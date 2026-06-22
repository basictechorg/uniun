import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/repositories/llm_credentials_repository.dart';
import 'package:uniun/domain/repositories/llm_repository.dart';

// ── Capability ────────────────────────────────────────────────────────────────

@lazySingleton
class HasActiveLlmModelUseCase extends NoParamsUseCase<bool> {
  final LlmRepository _repo;
  const HasActiveLlmModelUseCase(this._repo);

  @override
  Future<bool> call() => _repo.hasActiveModel();
}

// ── Session lifecycle ─────────────────────────────────────────────────────────

@lazySingleton
class OpenLlmConversationUseCase
    extends NoParamsUseCase<Either<Failure, Unit>> {
  final LlmRepository _repo;
  const OpenLlmConversationUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call() => _repo.openConversation();
}

@lazySingleton
class CloseLlmConversationUseCase
    extends NoParamsUseCase<Either<Failure, Unit>> {
  final LlmRepository _repo;
  const CloseLlmConversationUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call() => _repo.closeConversation();
}

// ── Streaming chat ────────────────────────────────────────────────────────────

class SendChatStreamInput {
  const SendChatStreamInput({
    required this.message,
    this.systemInstruction,
    this.cleanHistory = const [],
  });
  final String message;

  /// Persona + any branch/seed context, passed per turn (not stored on the
  /// backend) so independent chat surfaces don't clobber each other.
  final String? systemInstruction;
  final List<(String, String)> cleanHistory;
}

@lazySingleton
class SendChatStreamUseCase extends StreamUseCase<String, SendChatStreamInput> {
  final LlmRepository _repo;
  const SendChatStreamUseCase(this._repo);

  @override
  Stream<String> call(SendChatStreamInput input) => _repo.sendChat(
        message: input.message,
        systemInstruction: input.systemInstruction,
        cleanHistory: input.cleanHistory,
      );
}

// ── One-shot extraction ───────────────────────────────────────────────────────

class GenerateOneShotInput {
  const GenerateOneShotInput({
    required this.prompt,
    this.maxTokens = 1024,
    this.highPriority = false,
  });
  final String prompt;
  final int maxTokens;
  final bool highPriority;
}

@lazySingleton
class GenerateOneShotUseCase
    extends UseCase<Either<Failure, String?>, GenerateOneShotInput> {
  final LlmRepository _repo;
  const GenerateOneShotUseCase(this._repo);

  @override
  Future<Either<Failure, String?>> call(
    GenerateOneShotInput input, {
    bool cached = false,
  }) =>
      _repo.generateOneShot(
        prompt: input.prompt,
        maxTokens: input.maxTokens,
        highPriority: input.highPriority,
      );
}

// ── Priority coordination ─────────────────────────────────────────────────────

@lazySingleton
class PreemptBackgroundWorkUseCase
    extends NoParamsUseCase<Either<Failure, Unit>> {
  final LlmRepository _repo;
  const PreemptBackgroundWorkUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call() => _repo.preemptBackgroundWork();
}

@lazySingleton
class ResumeBackgroundWorkUseCase
    extends NoParamsUseCase<Either<Failure, Unit>> {
  final LlmRepository _repo;
  const ResumeBackgroundWorkUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call() => _repo.resumeBackgroundWork();
}

// ── Backend / model selection ─────────────────────────────────────────────────

@lazySingleton
class GetActiveLlmBackendUseCase
    extends NoParamsUseCase<Either<Failure, LlmBackendType>> {
  final LlmRepository _repo;
  const GetActiveLlmBackendUseCase(this._repo);

  @override
  Future<Either<Failure, LlmBackendType>> call() => _repo.getActiveBackend();
}

@lazySingleton
class SetActiveLlmBackendUseCase
    extends UseCase<Either<Failure, Unit>, LlmBackendType> {
  final LlmRepository _repo;
  const SetActiveLlmBackendUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call(
    LlmBackendType backend, {
    bool cached = false,
  }) =>
      _repo.setActiveBackend(backend);
}

@lazySingleton
class ListAvailableLlmModelsUseCase
    extends NoParamsUseCase<Either<Failure, List<LlmModelInfo>>> {
  final LlmRepository _repo;
  const ListAvailableLlmModelsUseCase(this._repo);

  @override
  Future<Either<Failure, List<LlmModelInfo>>> call() =>
      _repo.listAvailableModels();
}

@lazySingleton
class SetActiveLlmModelUseCase
    extends UseCase<Either<Failure, Unit>, String> {
  final LlmRepository _repo;
  const SetActiveLlmModelUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call(String modelId, {bool cached = false}) =>
      _repo.setActiveModel(modelId);
}

@lazySingleton
class GetActiveLlmModelUseCase
    extends NoParamsUseCase<Either<Failure, LlmModelInfo?>> {
  final LlmRepository _repo;
  const GetActiveLlmModelUseCase(this._repo);

  @override
  Future<Either<Failure, LlmModelInfo?>> call() => _repo.getActiveModel();
}

// ── Credentials ───────────────────────────────────────────────────────────────

@lazySingleton
class SaveOpenRouterKeyUseCase
    extends UseCase<Either<Failure, Unit>, String> {
  final LlmCredentialsRepository _repo;
  const SaveOpenRouterKeyUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call(String key, {bool cached = false}) =>
      _repo.saveOpenRouterKey(key);
}

@lazySingleton
class ClearOpenRouterKeyUseCase
    extends NoParamsUseCase<Either<Failure, Unit>> {
  final LlmCredentialsRepository _repo;
  const ClearOpenRouterKeyUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call() => _repo.clearOpenRouterKey();
}

@lazySingleton
class HasOpenRouterKeyUseCase extends NoParamsUseCase<bool> {
  final LlmCredentialsRepository _repo;
  const HasOpenRouterKeyUseCase(this._repo);

  @override
  Future<bool> call() => _repo.hasOpenRouterKey();
}
