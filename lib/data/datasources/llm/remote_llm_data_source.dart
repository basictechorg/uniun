import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:openrouter_api/openrouter_api.dart';
// OpenRouterInference is the concrete return type of OpenRouter.inference(...)
// but isn't re-exported from the public barrel. Import directly.
// ignore: implementation_imports
import 'package:openrouter_api/src/models/open_router_inference.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/data/datasources/llm/llm_data_source.dart';
import 'package:uniun/data/datasources/llm/llm_preferences_data_source.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';

/// Cloud LLM backend backed by [OpenRouter].
///
/// One API key unlocks every major frontier model (GPT, Claude, Gemini,
/// Llama, Mistral, etc.). The user pastes a key in Settings → we expose all
/// of OpenRouter's catalogue in the in-chat model picker.
///
/// Cancellation: callers cancel the `StreamSubscription` they get back from
/// [sendChat]. The `openrouter_api` package wraps each `streamCompletion`
/// in a Dio `CancelToken` and cleans up in its `finally`, so when the outer
/// `await for` exits the underlying HTTP request is torn down.
@lazySingleton
class RemoteLlmDataSource implements LlmDataSource {
  final LlmCredentialsDataSource _credentials;
  final LlmPreferencesDataSource _prefs;

  /// Cached, lazily constructed when a key becomes available.
  OpenRouterInference? _inference;

  /// In-flight extraction subscription. Held so [preemptBackgroundWork] and
  /// [sendChat] can cancel it when the user wants to free the engine for a
  /// chat turn.
  StreamSubscription<String>? _extractionSub;

  RemoteLlmDataSource(this._credentials, this._prefs);

  Future<OpenRouterInference?> _client() async {
    final existing = _inference;
    if (existing != null) return existing;
    final key = await _credentials.getOpenRouterKey();
    if (key == null || key.isEmpty) return null;
    return _inference = OpenRouter.inference(
      key: key,
      appId: 'in.uniun',
      appTitle: 'UNIUN',
    );
  }

  /// Forget the cached client. Call when the user disconnects / replaces the
  /// API key so the next call rebuilds with fresh credentials.
  void invalidateClient() => _inference = null;

  @override
  Future<bool> hasActiveModel() async {
    if (!await _credentials.hasOpenRouterKey()) return false;
    return _prefs.activeCloudModelId != null;
  }

  // ── Conversation session ────────────────────────────────────────────────
  // OpenRouter is stateless — we always send the full prompt.
  // openConversation/closeConversation are no-ops here.

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
    // Preempt any in-flight extraction so its HTTP request doesn't keep
    // racing chat for the user's quota.
    final extraction = _extractionSub;
    if (extraction != null) {
      await extraction.cancel();
      _extractionSub = null;
    }

    final inference = await _client();
    if (inference == null) {
      throw const _RemoteLlmException('No OpenRouter API key configured');
    }
    final modelId = _prefs.activeCloudModelId;
    if (modelId == null) {
      throw const _RemoteLlmException(
        'No cloud model selected. Pick one from the chat input picker.',
      );
    }

    // The OpenRouter wrapper exposes no system role here yet (Phase 3), so fold
    // the per-turn system instruction into the leading user content — matching
    // the local-backend fallback. TODO: use a real system message when the
    // wrapper supports it.
    final hasSystem =
        systemInstruction != null && systemInstruction.isNotEmpty;
    final leadingUser = hasSystem ? '$systemInstruction\n\n$message' : message;
    final messages = <LlmMessage>[
      for (final (q, a) in cleanHistory) ...[
        LlmMessage.user(LlmMessageContent.text(q)),
        LlmMessage.assistant(a),
      ],
      LlmMessage.user(LlmMessageContent.text(leadingUser)),
    ];

    try {
      await for (final chunk in inference.streamCompletion(
        modelId: modelId,
        messages: messages,
      )) {
        if (chunk.choices.isEmpty) continue;
        final token = chunk.choices.first.content;
        if (token.isNotEmpty) yield token;
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
    bool highPriority = false, // no local queue — flag is ignored for remote
  }) async {
    final inference = await _client();
    if (inference == null) {
      return const Right(null); // No key — caller treats null as skip.
    }
    final modelId = _prefs.activeCloudModelId;
    if (modelId == null) return const Right(null);

    final completer = Completer<String?>();
    final buffer = StringBuffer();

    _extractionSub?.cancel();
    _extractionSub = inference
        .streamCompletion(
          modelId: modelId,
          maxTokens: maxTokens,
          messages: [LlmMessage.user(LlmMessageContent.text(prompt))],
        )
        .map((r) => r.choices.isNotEmpty ? r.choices.first.content : '')
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
  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels() async {
    try {
      final inference = await _client();
      if (inference == null) return const Right([]);
      final models = await inference.listModels();
      final infos = models
          .map((m) => LlmModelInfo(
                id: m.id,
                displayName: m.name,
                backend: LlmBackendType.openRouter,
                // openrouter_api 1.0.2 doesn't expose context_length on
                // LlmModel; budgets fall back to a cloud default until we
                // hydrate this from a raw HTTP call.
                contextWindow: 0,
                pricePerMillionInput: m.inputCost > 0 ? m.inputCost * 1e6 : null,
                pricePerMillionOutput:
                    m.outputCost > 0 ? m.outputCost * 1e6 : null,
              ))
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return Right(infos);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}

class _RemoteLlmException implements Exception {
  final String message;
  const _RemoteLlmException(this.message);
  @override
  String toString() => message;
}
