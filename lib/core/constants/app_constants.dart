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
}
