import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/cloud/uniun_cloud_auth.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/datasources/llm/llm_data_source.dart';
import 'package:uniun/data/datasources/llm/llm_preferences_data_source.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';

/// Cloud LLM backend backed by the UNIUN inference gateway.
///
/// Auth is the user's own Nostr keypair ([UniunCloudAuth] silently logs in
/// and stores the `uk_` key on first use — no key to paste). The gateway is
/// OpenAI-compatible, so chat carries a REAL system role and SSE streaming.
///
/// Model access is plan-gated server-side (`403 model_not_allowed`);
/// [listAvailableModels] pre-filters the catalog to the account's plan so
/// the picker only offers models that will actually serve.
///
/// Cancellation: callers cancel the `StreamSubscription` they get back from
/// [sendChat]; exiting the `await for` tears down the underlying request.
@lazySingleton
class RemoteLlmDataSource implements LlmDataSource {
  final UniunGatewayClient _gateway;
  final UniunCloudAuth _auth;
  final LlmPreferencesDataSource _prefs;

  /// In-flight extraction subscription. Held so [preemptBackgroundWork] and
  /// [sendChat] can cancel it when the user wants the network for a chat.
  StreamSubscription<String>? _extractionSub;

  RemoteLlmDataSource(this._gateway, this._auth, this._prefs);

  @override
  Future<bool> hasActiveModel() async {
    if (!await _auth.hasStoredKey()) return false;
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

    final apiKey = await _auth.ensureApiKey();
    if (apiKey == null) {
      throw const _RemoteLlmException(
          'Sign in to UNIUN before using cloud AI');
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
      yield* _gateway.streamChatCompletion(
        apiKey: apiKey,
        modelId: modelId,
        messages: messages,
      );
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
  }) async {
    final String? apiKey;
    try {
      apiKey = await _auth.ensureApiKey();
    } catch (_) {
      return const Right(null); // Not connected — caller treats null as skip.
    }
    if (apiKey == null) return const Right(null);
    final modelId = _prefs.activeCloudModelId;
    if (modelId == null) return const Right(null);

    final completer = Completer<String?>();
    final buffer = StringBuffer();

    _extractionSub?.cancel();
    _extractionSub = _gateway
        .streamChatCompletion(
          apiKey: apiKey,
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
  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels() async {
    try {
      final apiKey = await _auth.ensureApiKey();
      if (apiKey == null) return const Right([]);

      // Catalog is public; the account's plan decides what actually serves.
      // `backend == "local"` rows are on-device models — never cloud-callable.
      final catalog = await _gateway.listModels();
      final profile = await _gateway.getProfile(apiKey);
      final plan = profile['plan'] as String?;
      final plans = await _gateway.listPlans();
      final allowed = <String>{
        for (final p in plans)
          if (p['name'] == plan)
            ...((p['models'] as List<dynamic>? ?? const []).cast<String>()),
      };

      // Gateway rule (usage.Engine.ModelAllowed): an EMPTY plan model list
      // means every model is allowed — that's the credits tier.
      final infos = [
        for (final m in catalog)
          if (!m.isLocalOnly && (allowed.isEmpty || allowed.contains(m.id)))
            LlmModelInfo(
              id: m.id,
              displayName: m.displayName,
              backend: LlmBackendType.uniunCloud,
            ),
      ]..sort((a, b) => a.displayName.compareTo(b.displayName));
      return Right(infos);
    } on UniunKeyUnavailableException catch (e) {
      return Left(Failure.errorFailure(e.toString()));
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
