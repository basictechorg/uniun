import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/utils/llm_text_sanitizer.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/local_inference_queue.dart';
import 'package:uniun/data/datasources/llm/local_model_params.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';

/// Wraps flutter_gemma 0.16.x for token-streaming inference.
///
/// ## Why 0.16 matters
///
/// 0.13.x had a single shared LiteRT-LM native session under every Dart
/// [InferenceChat] wrapper. `stopGeneration()` on the extraction wrapper
/// cancelled whatever chat was streaming and the next `nativeSendMessageAsync`
/// dereferenced a freed pointer → SIGSEGV. So we couldn't preempt extraction
/// when the user opened the Shiv tab.
///
/// 0.16's [InferenceModel.openChat] gives each Dart wrapper its **own**
/// independent native session, so `stopGeneration()` is per-session. We can
/// now safely cancel extraction the moment chat is requested, without
/// touching chat's session state.
///
/// ## Strategy
///
/// - **Chat** opens a throwaway [InferenceChat] per turn via [openChat]. RAG
///   context can change every turn so we don't want stale RAG dumps living in
///   a long-lived chat's history. Re-opening per turn is cheap on 0.16 because
///   each openChat just spawns a fresh session against the loaded weights.
/// - **Extraction** also uses [openChat], but we cache the in-flight reference
///   in [_activeExtraction] so that [sendAndStream] can call
///   `stopGeneration()` on it before the chat turn starts. Extraction's future
///   exits cleanly with a `null` result; the caller treats null as
///   "cancelled, retry later" (already handled by ExtractKnowledgeUseCase).
/// - [ModelTaskQueue] still serialises because the **native accelerator**
///   itself runs one inference at a time. The new contract is: preempt first
///   (cancel extraction), then chat enters the high-priority lane and waits
///   only for the very brief window the cancelled extraction takes to
///   actually stop.
@lazySingleton
class AIModelRunner {
  final ModelTaskQueue _queue;
  final AppSettingsStore _settings;

  /// In-flight extraction chat, if any. Held so [sendAndStream] can call
  /// [InferenceChat.stopGeneration] on it. Cleared in extraction's finally.
  InferenceChat? _activeExtraction;

  /// The model instance last handed out by [_openActiveModel]. Held so a failed
  /// invoke can [_resetModel] it — closing the native model frees its
  /// accumulated sessions/cache so the next open rebuilds a fresh one.
  InferenceModel? _activeModel;

  AIModelRunner(this._queue, this._settings);

  LocalModelParams? get _activeParams =>
      LocalModelParams.forId(_settings.activeModelId);

  /// Backend that actually worked for the current model. We prefer GPU, but
  /// the Metal GPU delegate cannot be applied to every model on every device —
  /// large LiteRT graphs trip Metal's 31-texture-binding limit
  /// ("texture binding ... index 31 that is greater than 30") and the iOS
  /// simulator has no usable GPU delegate at all. On the first GPU failure we
  /// retry on CPU and remember it so later turns skip the doomed GPU attempt.
  /// Reset whenever the active model changes, to re-probe GPU for the new one.
  PreferredBackend _backend = PreferredBackend.gpu;
  AIModelId? _backendForModel;

  /// Open the active model, falling back GPU → CPU on engine-creation failure.
  Future<InferenceModel> _openActiveModel(int maxTokens) async {
    final activeId = _settings.activeModelId;
    if (activeId != _backendForModel) {
      _backendForModel = activeId;
      _backend = PreferredBackend.gpu;
    }
    try {
      return _activeModel = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: _backend,
      );
    } catch (e) {
      if (_backend == PreferredBackend.cpu) rethrow;
      debugPrint('⚠️ GPU backend failed to open model ($e) — retrying on CPU');
      return _activeModel = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
      );
    }
  }

  /// Close the cached native model so the next [_openActiveModel] rebuilds a
  /// fresh one. Used to recover when an invoke fails after the native runtime
  /// has degraded over many open/close session cycles (common on the
  /// resource-limited iOS simulator). flutter_gemma's close-listener resets its
  /// singleton, so a later getActiveModel re-creates the model.
  Future<void> _resetModel() async {
    final m = _activeModel;
    _activeModel = null;
    if (m == null) return;
    try {
      await m.close();
    } catch (_) {
      // Already closing / closed — fine.
    }
  }

  bool get hasActiveModel => FlutterGemma.hasActiveModel();

  /// Validate that a model is active before a conversation opens. The runner
  /// holds NO per-conversation state — the system instruction is passed into
  /// [sendAndStream] per turn so independent chat surfaces (e.g. the Shiv tab
  /// and an inline composer chat) can't clobber each other.
  Future<void> initChat() async {
    if (!FlutterGemma.hasActiveModel()) {
      throw StateError('No AI model is active. Please select a model first.');
    }
  }

  /// Send the current user [message] (question + RAG context if any) and
  /// stream text tokens back.
  ///
  /// [cleanHistory] is the previous turns of this conversation as bare
  /// (user, assistant) text pairs — no RAG, no system prompt. They are
  /// replayed into the freshly-opened chat so the model has continuity
  /// without the bloat.
  Stream<String> sendAndStream(
    String message, {
    required String systemInstruction,
    List<(String, String)> cleanHistory = const [],
  }) async* {
    if (!FlutterGemma.hasActiveModel()) {
      throw StateError('No AI model is active. Please select a model first.');
    }

    // Preempt any in-flight extraction. Safe in 0.16 because openChat sessions
    // are independent — stopping extraction does not touch chat's session.
    final extraction = _activeExtraction;
    if (extraction != null) {
      debugPrint('🚫 Preempting in-flight extraction for chat turn');
      try {
        await extraction.stopGeneration();
      } catch (e) {
        debugPrint('⚠️ stopGeneration on extraction threw: $e');
      }
    }

    final tokens = StreamController<String>();
    final running = _queue.runHigh<void>(() async {
      InferenceChat? chat;
      try {
        final params = _activeParams;
        final model = await _openActiveModel(params?.maxTokens ?? 4096);
        chat = await model.openChat(
          temperature: 0.8,
          topK: 40,
          tokenBuffer: 512,
          modelType: params?.modelType,
          isThinking: params?.isThinking ?? false,
        );

        final prompt = _composePrompt(
          systemInstruction: systemInstruction,
          cleanHistory: cleanHistory,
          currentMessage: message,
          historyBudget: _historyBudgetTokens(params),
        );

        await chat.addQueryChunk(Message.text(text: prompt));
        final scrubber = _StopTokenScrubber();
        await for (final response in chat.generateChatResponseAsync()) {
          if (response is TextResponse && response.token.isNotEmpty) {
            final safe = scrubber.feed(response.token);
            if (safe != null) tokens.add(safe);
            if (scrubber.isDone) break;
          }
        }
        final tail = scrubber.flush();
        if (tail != null) tokens.add(tail);
      } catch (e, st) {
        tokens.addError(e, st);
      } finally {
        await chat?.close();
        await tokens.close();
      }
    }, label: 'chat');

    unawaited(running);
    yield* tokens.stream;
  }

  /// No-op: chat opens a throwaway session per turn, so there is no long-lived
  /// per-conversation state to tear down. Kept for the datasource lifecycle.
  Future<void> close() async {}

  /// Stateless one-shot completion. By default goes through the low-priority
  /// lane so chat turns always cut in front. Pass [highPriority] = true for
  /// foreground user work (e.g. Manthan deck generation) so it runs even
  /// while the Shiv tab holds the low lane paused. May return null if
  /// preempted by chat or if no model is active — callers must tolerate null.
  Future<String?> generateOneShot(
    String prompt, {
    int maxTokens = 1024,
    bool highPriority = false,
  }) {
    if (!FlutterGemma.hasActiveModel()) {
      debugPrint('⏭️ generateOneShot: no active model');
      return Future.value(null);
    }
    return (highPriority ? _queue.runHigh<String?> : _queue.runLow<String?>)(
      () => _doGenerateOneShot(prompt, maxTokens),
      label: highPriority ? 'manthan' : 'extract',
    );
  }

  Future<String?> _doGenerateOneShot(String prompt, int maxTokens) async {
    final (result, ok) = await _attemptOneShot(prompt, maxTokens);
    if (ok) return result;
    // The invoke failed. After many open/close session cycles the native
    // runtime can degrade — invoke starts failing even though it worked
    // moments ago (seen heavily on the resource-limited iOS simulator). Drop
    // the cached model so a fresh one is rebuilt, then retry once. If it still
    // fails, the caller treats null as "skip this combo".
    debugPrint('⚠️ generateOneShot: invoke failed — resetting model + retry');
    await _resetModel();
    final (retryResult, _) = await _attemptOneShot(prompt, maxTokens);
    return retryResult;
  }

  /// One open → generate → close attempt. Returns `(text, true)` on success or
  /// `(null, false)` when the native invoke threw, so the caller can decide
  /// whether to reset the model and retry.
  Future<(String?, bool)> _attemptOneShot(String prompt, int maxTokens) async {
    InferenceChat? oneShot;
    try {
      debugPrint('🧪 generateOneShot: opening throwaway chat…');
      final params = _activeParams;
      // Open at the model's baked-in KV-cache size (see [LocalModelParams.
      // maxTokens]) — exactly like chat does. It is NOT a free choice: opening
      // SMALLER than the baked size (e.g. a caller's 512) makes the compiled
      // graph fail at invoke ("Failed to invoke the compiled model"), which
      // strands the Manthan deck. The requested [maxTokens] is only a fallback
      // for an unknown model with no params.
      final cacheSize = params?.maxTokens ?? maxTokens;
      final model = await _openActiveModel(cacheSize);
      oneShot = await model.openChat(
        temperature: 0.2,
        topK: 20,
        tokenBuffer: 256,
        modelType: params?.modelType,
        isThinking: params?.isThinking ?? false,
      );
      _activeExtraction = oneShot;

      await oneShot.addQueryChunk(Message.text(text: prompt));
      final buffer = StringBuffer();
      final scrubber = _StopTokenScrubber();
      await for (final response in oneShot.generateChatResponseAsync()) {
        if (response is TextResponse) {
          final safe = scrubber.feed(response.token);
          if (safe != null) buffer.write(safe);
          if (scrubber.isDone) break;
        }
      }
      final tail = scrubber.flush();
      if (tail != null) buffer.write(tail);
      // Sanitize once on the full buffer — strips tool-call envelopes,
      // BPE `Ġ` markers, and repairs Latin-1-encoded UTF-8 mojibake
      // (e.g. emojis arriving as `ðŁĮ±`). Mojibake repair MUST run on the
      // whole string, not per-chunk, or we'd split UTF-8 byte sequences.
      final cleaned = LlmTextSanitizer.clean(buffer.toString());
      debugPrint('🧪 generateOneShot: done (${cleaned.length} chars)');
      return (cleaned, true);
    } catch (e, st) {
      debugPrint('⏭️ generateOneShot attempt failed: $e\n$st');
      return (null, false);
    } finally {
      if (identical(_activeExtraction, oneShot)) {
        _activeExtraction = null;
      }
      try {
        await oneShot?.close();
      } catch (_) {
        // Safe to ignore — session may already be in a closing state.
      }
    }
  }

  /// Build the per-turn prompt: persona/system + clean history + new turn.
  ///
  /// Format keeps it explicit so the model knows turn boundaries:
  ///   <system>
  ///   User: <q1>
  ///   Assistant: <a1>
  ///   User: <q2>
  ///   Assistant: <a2>
  ///   <current message, which already contains RAG + question>
  String _composePrompt({
    required String systemInstruction,
    required List<(String, String)> cleanHistory,
    required String currentMessage,
    required int historyBudget,
  }) {
    final buf = StringBuffer();
    buf.write(systemInstruction);
    if (!systemInstruction.endsWith('\n')) buf.writeln();

    final kept = _trimHistory(cleanHistory, historyBudget);
    for (final (q, a) in kept) {
      buf.writeln();
      buf.writeln('User: $q');
      buf.writeln('Assistant: $a');
    }
    buf.writeln();
    buf.write(currentMessage);
    return buf.toString();
  }

  int _historyBudgetTokens(LocalModelParams? params) {
    final max = params?.maxTokens ?? 1024;
    return (max * 0.20).round();
  }

  List<(String, String)> _trimHistory(
    List<(String, String)> history,
    int budgetTokens,
  ) {
    if (history.isEmpty || budgetTokens <= 0) return const [];
    final kept = <(String, String)>[];
    int used = 0;
    for (final pair in history.reversed) {
      final line = 'User: ${pair.$1}\nAssistant: ${pair.$2}\n';
      final cost = (line.length / 4).ceil();
      if (used + cost > budgetTokens) break;
      kept.insert(0, pair);
      used += cost;
    }
    return kept;
  }
}

/// Strips per-model stop tokens from a streaming token feed.
///
/// flutter_gemma 0.16.5's [StopTokenFilter] only matches `<end_of_turn>` (Gemma).
/// On iOS the MediaPipe `.litertlm` backend does not honour stop tokens itself,
/// so non-Gemma models (Qwen, DeepSeek, Llama) leak their terminator plus BPE
/// byte-level junk after it. We catch the rest here. Safe on Android too —
/// these tokens simply never appear there.
class _StopTokenScrubber {
  static const _stopTokens = <String>[
    '<|im_end|>',                  // Qwen
    '<|endoftext|>',               // Qwen / GPT-style alt
    '<end_of_turn>',               // Gemma (already filtered upstream; harmless)
    '<｜end▁of▁sentence｜>',      // DeepSeek (full-width pipes + underscores)
    '<|eot_id|>',                  // Llama 3
  ];

  String _buffer = '';
  bool _done = false;

  bool get isDone => _done;

  String? feed(String chunk) {
    if (_done) return null;
    _buffer += chunk;

    int earliest = -1;
    for (final s in _stopTokens) {
      final i = _buffer.indexOf(s);
      if (i >= 0 && (earliest < 0 || i < earliest)) earliest = i;
    }
    if (earliest >= 0) {
      final out = _buffer.substring(0, earliest);
      _buffer = '';
      _done = true;
      return out.isEmpty ? null : out;
    }

    // Hold back any tail that could be the start of a stop token spanning
    // the next chunk.
    int hold = 0;
    for (final s in _stopTokens) {
      final maxI = s.length - 1 < _buffer.length ? s.length - 1 : _buffer.length;
      for (int i = 1; i <= maxI; i++) {
        if (_buffer.endsWith(s.substring(0, i)) && i > hold) hold = i;
      }
    }

    if (hold == 0) {
      final out = _buffer;
      _buffer = '';
      return out.isEmpty ? null : out;
    }
    final out = _buffer.substring(0, _buffer.length - hold);
    _buffer = _buffer.substring(_buffer.length - hold);
    return out.isEmpty ? null : out;
  }

  String? flush() {
    if (_done || _buffer.isEmpty) return null;
    final out = _buffer;
    _buffer = '';
    return out;
  }
}
