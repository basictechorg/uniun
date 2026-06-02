import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';

/// Per-backend inference contract. One impl per backend
/// ([LocalLlmDataSource], [RemoteLlmDataSource]). The Repository owns
/// backend selection and dispatches to one of these.
abstract class LlmDataSource {
  /// True if this backend is ready to serve inference.
  /// Local: a Gemma model is installed.
  /// Remote: an API key is configured.
  Future<bool> hasActiveModel();

  /// Open or reuse a long-lived conversation context. Local backend uses
  /// this to hold a persistent `InferenceChat` (Phase 2+); the remote
  /// backend is stateless so this is a no-op there.
  Future<Either<Failure, Unit>> openConversation({String? systemInstruction});

  /// Tear down the conversation context.
  Future<Either<Failure, Unit>> closeConversation();

  /// Stream tokens for a chat turn.
  Stream<String> sendChat({
    required String message,
    List<(String, String)> cleanHistory = const [],
  });

  /// One-shot completion for background extraction.
  Future<Either<Failure, String?>> generateOneShot({
    required String prompt,
    int maxTokens = 1024,
  });

  /// Backend-specific coordination — local pauses its low-priority queue;
  /// remote is naturally parallel so this is a no-op.
  Future<Either<Failure, Unit>> preemptBackgroundWork();

  Future<Either<Failure, Unit>> resumeBackgroundWork();

  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels();
}
