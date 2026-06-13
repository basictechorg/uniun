/// Application-wide constants.
///
/// Use these instead of hardcoding the same literal in multiple places.
class AppConstants {
  AppConstants._();

  /// The application name — also used as a fallback seed for generated avatars.
  static const String kAppName = 'uniun';

  /// Human-readable brand name shown in UI.
  static const String kBrandName = 'UNIUN';

  /// App version string shown in settings / privacy policy.
  static const String kAppVersion = 'UNIUN v1.0.0-beta';

  /// Privacy contact email.
  static const String kPrivacyEmail = 'info@uniun.in';

  /// The UNIUN backend relay — the default system relay every device connects
  /// to and the one auto-selected when publishing. Use this constant instead
  /// of hardcoding the URL anywhere.
  static const String kUniunBackend = 'wss://dev.uniun.in:8080';

  /// HTTP base for our backend's Blossom (NIP-B7) endpoints. Same host as
  /// [kUniunBackend], HTTPS instead of WSS. The Go relay wires
  /// `blossom.New(relay, RelayURL)` against this URL — `PUT /upload`,
  /// `GET /<sha256>`, `HEAD /<sha256>`, etc. live here.
  static const String kUniunBlossom = 'https://dev.uniun.in:8080';

  /// Max bytes the client will attempt to send to the Blossom server.
  /// nginx in front of the relay now caps request body at 100 MB; we keep
  /// a much tighter client-side budget for two reasons:
  ///   1. Photos at this size already cover any reasonable quality — going
  ///      bigger just wastes the receiver's data plan.
  ///   2. A 100 MB ceiling on the relay is the *safety net*, not the goal.
  /// Images over this are auto-compressed with a more generous quality
  /// schedule; videos and arbitrary files are rejected past the cap.
  static const int kMaxUploadBytes = 3 * 1024 * 1024;
}
