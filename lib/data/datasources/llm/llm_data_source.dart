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

  /// Validate / open a conversation session (local: model-active check;
  /// remote: no-op). Holds NO per-conversation state — the system instruction
  /// rides on each [sendChat] turn so independent chat surfaces don't clobber.
  Future<Either<Failure, Unit>> openConversation();

  /// Tear down the conversation context.
  Future<Either<Failure, Unit>> closeConversation();

  /// Stream tokens for a chat turn. [systemInstruction] is passed per turn
  /// (persona + any branch/seed context) rather than stored on the backend.
  Stream<String> sendChat({
    required String message,
    String? systemInstruction,
    List<(String, String)> cleanHistory = const [],
  });

  /// One-shot completion for background extraction.
  /// Pass [highPriority] = true for foreground user work (e.g. Nataraj deck)
  /// so the task runs even while the low lane is paused.
  Future<Either<Failure, String?>> generateOneShot({
    required String prompt,
    int maxTokens = 1024,
    bool highPriority = false,
  });

  /// Backend-specific coordination — local pauses its low-priority queue;
  /// remote is naturally parallel so this is a no-op.
  Future<Either<Failure, Unit>> preemptBackgroundWork();

  Future<Either<Failure, Unit>> resumeBackgroundWork();

  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels();
}
