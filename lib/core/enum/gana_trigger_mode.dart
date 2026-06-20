/// How a Gana fires once it's enabled.
///
/// Stored on `GanaModel` as `EnumType.name`. Defaults to [recurring]
/// because legacy rows (created before this field existed) should keep
/// behaving the way they did.
enum GanaTriggerMode {
  /// Fires once on the first matching trigger (reactive or interval),
  /// then auto-disables the Gana. The user re-enables manually to run
  /// it again. Useful for "draft me a reply once, then stop" tasks.
  oneShot,

  /// Fires every time a trigger matches, until the user disables it.
  /// This is the cron-job behaviour: keep going indefinitely.
  recurring,
}
