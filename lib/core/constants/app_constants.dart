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

  /// Target size for image uploads on platforms with a working compressor
  /// (Android / iOS / macOS / web). Photos over this get auto-compressed
  /// via `ImageCompressor` — 3 MB at 95q is indistinguishable from the raw
  /// shot to the human eye and saves every receiver bandwidth + cache
  /// space. This is the *compression target*, not a hard reject.
  static const int kMaxUploadBytes = 3 * 1024 * 1024;

  /// Image cap used on Windows specifically. `flutter_image_compress` has no
  /// Windows backend, so we skip compression entirely there and let users
  /// upload photos at native size up to this ceiling. Bigger than the
  /// 3 MB compressed target (no compression to bank against) but well
  /// under [kMaxBinaryUploadBytes] so a single shot can't blow the budget.
  static const int kMaxUploadBytesWindows = 10 * 1024 * 1024;

  /// Hard upload cap for non-image binaries — videos, PDFs, docs, archives,
  /// anything we can't shrink on-device. nginx in front of the relay accepts
  /// up to 100 MB; we leave headroom for HTTP overhead + the Kind 24242
  /// auth envelope and reject anything over this with a friendly snackbar.
  /// Bigger files need chunked upload (Blossom spec extension) which is a
  /// future deliverable.
  static const int kMaxBinaryUploadBytes = 50 * 1024 * 1024;
}
