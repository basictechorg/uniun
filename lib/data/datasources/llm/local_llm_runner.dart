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
        );

        await chat.addQueryChunk(Message.text(text: prompt));
        await for (final response in chat.generateChatResponseAsync()) {
          if (response is TextResponse && response.token.isNotEmpty) {
            tokens.add(response.token);
          }
        }
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
      await for (final response in oneShot.generateChatResponseAsync()) {
        if (response is TextResponse) buffer.write(response.token);
      }
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
  }) {
    final buf = StringBuffer();
    buf.write(systemInstruction);
    if (!systemInstruction.endsWith('\n')) buf.writeln();
    for (final (q, a) in cleanHistory) {
      buf.writeln();
      buf.writeln('User: $q');
      buf.writeln('Assistant: $a');
    }
    buf.writeln();
    buf.write(currentMessage);
    return buf.toString();
  }
}
