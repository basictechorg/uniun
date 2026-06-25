import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';

/// Single inference contract for the app.
///
/// Hides whether the active backend is on-device flutter_gemma or a cloud
/// API (OpenRouter, etc.). All callers — `ShivAIBloc`, `ExtractKnowledgeUseCase`,
/// future extraction or summarisation flows — go through this interface and
/// never touch a model engine directly.
///
/// Lifecycle:
///   1. (Optional) [openConversation] with a system instruction → opens or
///      reuses a chat session that remembers history across turns.
///   2. Each user turn → [sendChat] returns a `Stream<String>` of tokens.
///   3. [closeConversation] when the conversation ends or the user switches
///      branches → tears down the session.
///
/// Background one-shot work (knowledge extraction etc.) uses
/// [generateOneShot] which runs at a lower priority. [preemptBackgroundWork]
/// stops any in-flight low-priority work so a chat turn can start
/// immediately.
abstract class LlmRepository {
  /// True if the active backend has a usable model loaded.
  /// For local: a Gemma model is installed.
  /// For cloud: an API key is configured.
  Future<bool> hasActiveModel();

  // ── Conversation session ────────────────────────────────────────────────

  Future<Either<Failure, Unit>> openConversation();
  Future<Either<Failure, Unit>> closeConversation();

  // ── Per-turn inference ──────────────────────────────────────────────────

  /// Streams tokens for [message]. [systemInstruction] (persona + any branch/
  /// seed context) is passed per turn, not stored on the backend, so independent
  /// chat surfaces don't clobber each other. [cleanHistory] is the previous
  /// turns of the same conversation as bare (user, assistant) text pairs.
  ///
  /// Cancellation: cancel the returned StreamSubscription to abort.
  Stream<String> sendChat({
    required String message,
    String? systemInstruction,
    List<(String, String)> cleanHistory = const [],
  });

  // ── One-shot work ───────────────────────────────────────────────────────

  /// Stateless completion routed through [InferenceScheduler] (local
  /// backend) or executed directly (cloud backend, network-concurrent).
  ///
  /// [kind] drives scheduler tier selection — see
  /// `docs/SHIVA/scheduling.md` §3. Default is [LlmTaskKind.extract] which
  /// matches the original semantics of `generateOneShot` before the
  /// scheduler landed.
  Future<Either<Failure, String?>> generateOneShot({
    required String prompt,
    int maxTokens = 1024,
    LlmTaskKind kind = LlmTaskKind.extract,
  });

  // ── Priority coordination ───────────────────────────────────────────────

  /// Pause low-priority work (extraction) so chat can hold the engine.
  Future<Either<Failure, Unit>> preemptBackgroundWork();

  /// Resume low-priority work. Idempotent.
  Future<Either<Failure, Unit>> resumeBackgroundWork();

  // ── Backend selection ───────────────────────────────────────────────────

  Future<Either<Failure, LlmBackendType>> getActiveBackend();
  Future<Either<Failure, Unit>> setActiveBackend(LlmBackendType backend);

  /// Lists models available on the **active** backend. For local: returns
  /// the currently-loaded model if any. For cloud: the provider's model
  /// catalogue.
  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels();

  /// Pick a model on the active backend. For cloud, persists the chosen
  /// model id. For local, this is a no-op — local model selection happens
  /// via the existing model-download flow (AIModelSelectionPage).
  Future<Either<Failure, Unit>> setActiveModel(String modelId);

  /// The currently-active model on the active backend, if any.
  Future<Either<Failure, LlmModelInfo?>> getActiveModel();
}
