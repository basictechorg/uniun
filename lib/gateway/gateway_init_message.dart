/// Passed to [gatewayEntryPoint] when spawning the Gateway isolate.
///
/// Only plain Dart types — no Isar objects, no Flutter types.
/// Dart copies plain objects across isolate boundaries via [SendPort].
class GatewayInitMessage {
  /// Absolute path to the directory containing the Isar database file.
  /// Obtained in Isolate 1 via [getApplicationDocumentsDirectory()] and
  /// passed here so the Gateway isolate never needs Flutter plugins.
  final String isarDirectory;

  /// The active user's private key as raw hex (32 bytes).
  /// Decoded from nsec in Isolate 1 and passed here because
  /// [FlutterSecureStorage] is unavailable in background isolates.
  /// May be null before the user has logged in.
  final String? privkeyHex;

  /// The active user's public key as raw hex (secp256k1).
  /// Read from [UserKeyStore] (SharedPreferences) in Isolate 1 and passed
  /// here because SharedPreferences is unavailable in background isolates.
  /// May be null before the user has logged in.
  final String? pubkeyHex;

  const GatewayInitMessage({
    required this.isarDirectory,
    this.privkeyHex,
    this.pubkeyHex,
  });
}
