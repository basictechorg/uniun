import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/llm/llm_data_source.dart';
import 'package:uniun/data/datasources/llm/local_inference_queue.dart';
import 'package:uniun/data/datasources/llm/local_llm_runner.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/repositories/ai_model_repository.dart';

/// On-device flutter_gemma backend.
///
/// Wraps [AIModelRunner] (token streaming + one-shot) and [ModelTaskQueue]
/// (high/low priority coordination). The runner still does the engine work
/// today; Phase 2 will swap it to flutter_gemma 0.16 with persistent
/// per-conversation sessions. This data source's surface stays stable
/// through that change.
///
/// Registered as a concrete type rather than `as: LlmDataSource` so the
/// repository can hold both [LocalLlmDataSource] and [RemoteLlmDataSource]
/// without needing `@Named` qualifiers.
@lazySingleton
class LocalLlmDataSource implements LlmDataSource {
  final AIModelRunner _runner;
  final ModelTaskQueue _queue;
  final AIModelRepository _modelCatalog;

  LocalLlmDataSource(this._runner, this._queue, this._modelCatalog);

  @override
  Future<bool> hasActiveModel() async => _runner.hasActiveModel;

  // ── Conversation session ────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> openConversation({
    String? systemInstruction,
  }) async {
    try {
      await _runner.initChat(systemInstruction: systemInstruction);
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> closeConversation() async {
    try {
      await _runner.close();
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Per-turn streaming ──────────────────────────────────────────────────

  @override
  Stream<String> sendChat({
    required String message,
    List<(String, String)> cleanHistory = const [],
  }) {
    return _runner.sendAndStream(message, cleanHistory: cleanHistory);
  }

  // ── Background one-shot ─────────────────────────────────────────────────

  @override
  Future<Either<Failure, String?>> generateOneShot({
    required String prompt,
    int maxTokens = 1024,
  }) async {
    try {
      final result = await _runner.generateOneShot(prompt, maxTokens: maxTokens);
      return Right(result);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Priority coordination ───────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> preemptBackgroundWork() async {
    _queue.pauseLowPriority();
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> resumeBackgroundWork() async {
    _queue.resumeLowPriority();
    return const Right(unit);
  }

  // ── Model listing ───────────────────────────────────────────────────────

  /// For local, the "available models" are the downloaded ones. UI uses
  /// [AIModelRepository] directly for the catalog/download flow; this is
  /// here so the cross-backend picker can list a unified view.
  @override
  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels() async {
    try {
      final catalog = await _modelCatalog.getAvailableModels();
      final downloaded = await _modelCatalog.getDownloadedModelIds();
      final infos = catalog
          .where((m) => downloaded.contains(m.modelId))
          .map((m) => LlmModelInfo(
                id: m.modelId.name,
                displayName: _displayNameForLocal(m.modelId),
                backend: LlmBackendType.localGemma,
              ))
          .toList();
      return Right(infos);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// Fallback display name. UI layers should still prefer
  /// `AppLocalizations` keyed off [AIModelId].
  String _displayNameForLocal(AIModelId id) {
    switch (id) {
      case AIModelId.qwen25_05b:
        return 'Qwen3 0.6B';
      case AIModelId.deepseekR1:
        return 'DeepSeek R1 1.5B';
      case AIModelId.gemma4E2b:
        return 'Gemma 4 E2B';
      case AIModelId.gemma4E4b:
        return 'Gemma 4 E4B';
    }
  }
}
