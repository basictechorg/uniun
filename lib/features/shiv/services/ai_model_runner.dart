import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/features/shiv/services/model_task_queue.dart';

/// Wraps flutter_gemma 0.13.x for token-streaming inference.
///
/// Each user turn opens a fresh [InferenceChat] session built from:
///   - the persona/personalization system instruction (constant per session)
///   - last N clean (Q, A) pairs from the bloc's saved messages
///   - the per-turn RAG-enriched message
///
/// The native chat is closed at end of every turn. flutter_gemma's
/// `InferenceChat` accumulates the full RAG-enriched prompt in its internal
/// history; keeping it alive across turns bloats context with stale RAG dumps
/// from earlier turns. Re-opening each turn is the cost of clean history.
///
/// All model access flows through [ModelTaskQueue]:
///   - [sendAndStream] uses the high-priority lane.
///   - [generateOneShot] uses the low-priority lane (extraction).
@lazySingleton
class AIModelRunner {
  final ModelTaskQueue _queue;

  String? _systemInstruction;

  AIModelRunner(this._queue);

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

    // We do NOT preempt the in-flight extraction here. flutter_gemma 0.13.x
    // routes both Dart [InferenceChat] wrappers through one shared native
    // LiteRT-LM session; calling `stopGeneration` on the extraction wrapper
    // cancels whatever chat is currently streaming and leaves the next
    // `nativeSendMessageAsync` dereferencing a freed session pointer.
    // The queue serialises so chat runs immediately once extraction ends.

    final tokens = StreamController<String>();
    // Run the inference inside the high-priority lane; tokens flow out via
    // the controller while the lane future completes when generation ends.
    final running = _queue.runHigh<void>(() async {
      InferenceChat? chat;
      try {
        final model = await FlutterGemma.getActiveModel(maxTokens: 4096);
        chat = await model.createChat(
          temperature: 0.8,
          topK: 40,
          tokenBuffer: 512,
        );

        final prompt = _composePrompt(
          systemInstruction: _systemInstruction!,
          cleanHistory: cleanHistory,
          currentMessage: message,
        );

        await chat.addQuery(Message.text(text: prompt));
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

    // Unawaited; consumer reads tokens.stream until done. The future is
    // only used to propagate the queue's lifecycle.
    unawaited(running);
    yield* tokens.stream;
  }

  /// Dispose the current chat session (just forgets the system instruction).
  Future<void> close() async {
    _systemInstruction = null;
  }

  /// Stateless one-shot completion. Goes through the low-priority lane so
  /// chat turns always cut in front.
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
      final model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
      oneShot = await model.createChat(
        temperature: 0.2,
        topK: 20,
        tokenBuffer: 256,
      );
      await oneShot.addQuery(Message.text(text: prompt));
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
