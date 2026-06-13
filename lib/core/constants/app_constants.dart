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
  /// nginx in front of the relay caps request body at 1 MB; we target
  /// slightly under that to leave headroom for HTTP headers + the Kind
  /// 24242 auth event. Images larger than this are auto-compressed; videos
  /// and arbitrary files are rejected with a friendly snackbar.
  static const int kMaxUploadBytes = 950 * 1024;
}
