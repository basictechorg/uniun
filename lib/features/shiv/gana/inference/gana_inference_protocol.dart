import 'dart:isolate';

/// Cross-isolate protocol between the Gana engine (background isolate) and
/// the `GanaInferenceServer` running in the main isolate.
///
/// All types here MUST be primitives + `SendPort` so they can cross the
/// isolate boundary safely.

/// Engine → Server.
class GanaInferenceRequest {
  /// Fully-assembled prompt — task + input + knowledge + tool instructions.
  final String prompt;

  /// Optional id of the model the requestor expects to be active. When
  /// non-null and != server's current active model id, the server replies
  /// with [GanaInferenceResponseKind.skippedModelMismatch] without burning
  /// inference cycles. (The engine pre-checks this too, but it's a TOCTOU
  /// race — the active model can swap between gate and request arrival.)
  final String? expectedModelId;

  /// Optional generation cap. Null ⇒ server default.
  final int? maxTokens;

  /// Engine listens here for the response.
  final SendPort replyPort;

  const GanaInferenceRequest({
    required this.prompt,
    required this.replyPort,
    this.expectedModelId,
    this.maxTokens,
  });
}

/// Server → Engine.
enum GanaInferenceResponseKind {
  /// `body` carries the model's parsed `publish_message.body` argument
  /// (or the case-insensitive trimmed string `<NOOP>` if the model
  /// explicitly opted out).
  ok,

  /// `FlutterGemma.hasActiveModel() == false`. Engine treats as
  /// `GanaSkipReason.noActiveModel`.
  skippedNoActiveModel,

  /// Active model id != [GanaInferenceRequest.expectedModelId].
  skippedModelMismatch,

  /// `LocalLlmRunner.generateOneShot` returned null — preempted by Shiv
  /// chat, the model swapped mid-generation, or the runner gave up.
  /// Engine logs as `GanaSkipReason.modelSwapped` so the cursor is not
  /// advanced (next trigger picks up the same input cleanly).
  skippedCancelled,

  /// Parse error, exception, anything unexpected. `error` carries detail.
  failed,
}

class GanaInferenceResponse {
  final GanaInferenceResponseKind kind;
  final String? body;
  final String? error;

  const GanaInferenceResponse._({
    required this.kind,
    this.body,
    this.error,
  });

  factory GanaInferenceResponse.ok(String body) =>
      GanaInferenceResponse._(kind: GanaInferenceResponseKind.ok, body: body);

  factory GanaInferenceResponse.noActiveModel() =>
      const GanaInferenceResponse._(
          kind: GanaInferenceResponseKind.skippedNoActiveModel);

  factory GanaInferenceResponse.modelMismatch() =>
      const GanaInferenceResponse._(
          kind: GanaInferenceResponseKind.skippedModelMismatch);

  factory GanaInferenceResponse.cancelled() => const GanaInferenceResponse._(
      kind: GanaInferenceResponseKind.skippedCancelled);

  factory GanaInferenceResponse.failed(String error) => GanaInferenceResponse._(
        kind: GanaInferenceResponseKind.failed,
        error: error,
      );
}
