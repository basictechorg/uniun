import 'dart:isolate';

/// Passed to `ganaEntryPoint` when spawning the Gana isolate.
///
/// Plain Dart only — no Isar objects, no Flutter types. Carries the
/// SendPort the engine uses to bridge inference back to the main isolate.
class GanaInitMessage {
  /// Absolute path to the Isar DB. Same path the main isolate + gateway use.
  final String isarDirectory;

  /// Active user pubkey hex — needed by the input filter (drops notes
  /// authored by self → kills self-loops + Gana-to-Gana ping-pong).
  /// Null when no user is logged in; the engine no-ops in that case.
  final String? selfPubkeyHex;

  /// Send port to the main-isolate `GanaInferenceServer`. The engine sends
  /// inference requests on this port and listens for responses on a fresh
  /// `ReceivePort` it allocates per request.
  final SendPort mainInferencePort;

  const GanaInitMessage({
    required this.isarDirectory,
    required this.selfPubkeyHex,
    required this.mainInferencePort,
  });
}
