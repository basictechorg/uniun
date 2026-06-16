import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';
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

  String? _systemInstruction;

  /// In-flight extraction chat, if any. Held so [sendAndStream] can call
  /// [InferenceChat.stopGeneration] on it. Cleared in extraction's finally.
  InferenceChat? _activeExtraction;

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
      return await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: _backend,
      );
    } catch (e) {
      if (_backend == PreferredBackend.cpu) rethrow;
      debugPrint('⚠️ GPU backend failed to open model ($e) — retrying on CPU');
      return FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
      );
    }
  }

  bool get hasActiveModel => FlutterGemma.hasActiveModel();
  bool get hasChatSession => _systemInstruction != null;

  /// Initialise a chat *session* by remembering the system instruction.
  /// No native chat is opened here — each turn opens its own.
  Future<void> initChat({String? systemInstruction}) async {
    if (!FlutterGemma.hasActiveModel()) {
      throw StateError('No AI model is active. Please select a model first.');
    }
    _systemInstruction = systemInstruction;
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
    List<(String, String)> cleanHistory = const [],
  }) async* {
    if (_systemInstruction == null) {
      throw StateError('Call initChat() before sending messages.');
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
          systemInstruction: _systemInstruction!,
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

  /// Dispose the current chat session (just forgets the system instruction).
  Future<void> close() async {
    _systemInstruction = null;
  }

  /// Stateless one-shot completion. Goes through the low-priority lane so
  /// chat turns always cut in front. May return null if preempted by chat
  /// or if no model is active — callers must tolerate null.
  Future<String?> generateOneShot(String prompt, {int maxTokens = 1024}) {
    if (!FlutterGemma.hasActiveModel()) {
      debugPrint('⏭️ generateOneShot: no active model');
      return Future.value(null);
    }
    return _queue.runLow<String?>(
      () => _doGenerateOneShot(prompt, maxTokens),
      label: 'extract',
    );
  }

  Future<String?> _doGenerateOneShot(String prompt, int maxTokens) async {
    InferenceChat? oneShot;
    try {
      debugPrint('🧪 generateOneShot: opening throwaway chat…');
      final params = _activeParams;
      // Never exceed the model's hard cache size — the requested [maxTokens] is
      // only a ceiling for this task, capped by what the engine can open.
      final cap = params?.maxTokens ?? maxTokens;
      final model = await _openActiveModel(maxTokens < cap ? maxTokens : cap);
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
      debugPrint('🧪 generateOneShot: done (${buffer.length} chars)');
      return buffer.toString();
    } catch (e, st) {
      debugPrint('⏭️ generateOneShot terminated: $e\n$st');
      return null;
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
