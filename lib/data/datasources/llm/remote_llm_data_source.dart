import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/llm/llm_data_source.dart';
import 'package:uniun/data/datasources/llm/llm_preferences_data_source.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';

/// Cloud LLM backend backed by the UNIUN inference gateway.
///
/// [UniunRepository] is the only gateway-facing dependency — it owns the
/// raw HTTP client, the account's key, catalog filtering, and 401 recovery.
/// This class never sees a `uk_` key: it just asks for a model catalog or a
/// token stream and picks which model / builds the OpenAI-shaped message
/// list, which is the actual "cloud LLM chat" concern.
///
/// Cancellation: callers cancel the `StreamSubscription` they get back from
/// [sendChat]; exiting the `await for` tears down the underlying request.
@lazySingleton
class RemoteLlmDataSource implements LlmDataSource {
  final UniunRepository _uniun;
  final LlmPreferencesDataSource _prefs;

  /// In-flight extraction subscription. Held so [preemptBackgroundWork] and
  /// [sendChat] can cancel it when the user wants the network for a chat.
  StreamSubscription<String>? _extractionSub;

  RemoteLlmDataSource(this._uniun, this._prefs);

  @override
  Future<bool> hasActiveModel() async {
    if (!await _uniun.isConnected()) return false;
    return _prefs.activeCloudModelId != null;
  }

  // ── Conversation session ────────────────────────────────────────────────
  // The gateway is stateless — we always send the full prompt.

  @override
  Future<Either<Failure, Unit>> openConversation() async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> closeConversation() async => const Right(unit);

  // ── Streaming chat ──────────────────────────────────────────────────────

  @override
  Stream<String> sendChat({
    required String message,
    String? systemInstruction,
    List<(String, String)> cleanHistory = const [],
  }) async* {
    // Preempt any in-flight extraction so it doesn't race chat for the
    // user's plan quota.
    final extraction = _extractionSub;
    if (extraction != null) {
      await extraction.cancel();
      _extractionSub = null;
    }

    final modelId = _prefs.activeCloudModelId;
    if (modelId == null) {
      throw const _RemoteLlmException(
        'No cloud model selected. Pick one from the chat input picker.',
      );
    }

    final messages = <Map<String, String>>[
      if (systemInstruction != null && systemInstruction.isNotEmpty)
        {'role': 'system', 'content': systemInstruction},
      for (final (q, a) in cleanHistory) ...[
        {'role': 'user', 'content': q},
        {'role': 'assistant', 'content': a},
      ],
      {'role': 'user', 'content': message},
    ];

    try {
      // `await for` + `yield`, NOT `yield* stream`: an exception thrown by a
      // delegated async* stream is not caught by a `try` wrapping `yield*`.
      await for (final token
          in _uniun.streamChat(modelId: modelId, messages: messages)) {
        yield token;
      }
    } catch (e, st) {
      debugPrint('❌ RemoteLlmDataSource.sendChat failed: $e\n$st');
      rethrow;
    }
  }

  // ── One-shot ────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, String?>> generateOneShot({
    required String prompt,
    int maxTokens = 1024,
    LlmTaskKind kind = LlmTaskKind.extract, // no local queue — kind is ignored for remote
    String? modelIdOverride,
  }) async {
    final modelId = modelIdOverride ?? _prefs.activeCloudModelId;
    if (modelId == null) return const Right(null);

    final completer = Completer<String?>();
    final buffer = StringBuffer();

    _extractionSub?.cancel();
    _extractionSub = _uniun
        .streamChat(
          modelId: modelId,
          maxTokens: maxTokens,
          messages: [
            {'role': 'user', 'content': prompt},
          ],
        )
        .listen(
          buffer.write,
          onDone: () {
            if (!completer.isCompleted) completer.complete(buffer.toString());
            _extractionSub = null;
          },
          onError: (Object e, StackTrace st) {
            debugPrint('⏭️ RemoteLlmDataSource.generateOneShot error: $e');
            if (!completer.isCompleted) completer.complete(null);
            _extractionSub = null;
          },
          cancelOnError: true,
        );

    try {
      final result = await completer.future;
      return Right(result);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Priority coordination ───────────────────────────────────────────────
  // No queue for cloud — concurrent HTTP is fine. But we DO preempt
  // extraction so we don't burn the user's quota for results they likely
  // won't see while they're chatting.

  @override
  Future<Either<Failure, Unit>> preemptBackgroundWork() async {
    final sub = _extractionSub;
    if (sub != null) {
      await sub.cancel();
      _extractionSub = null;
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> resumeBackgroundWork() async =>
      const Right(unit);

  // ── Model listing ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels() =>
      _uniun.listAvailableModels();
}

class _RemoteLlmException implements Exception {
  final String message;
  const _RemoteLlmException(this.message);
  @override
  String toString() => message;
}
