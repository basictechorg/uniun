import 'package:flutter/material.dart';

/// User-selectable theme mode. Persisted in SharedPreferences via
/// `AppSettingsStore.themeMode`; drives `MaterialApp.themeMode` at the root.
enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get materialThemeMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  static AppThemeMode? fromName(String? raw) {
    if (raw == null) return null;
    for (final v in AppThemeMode.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}
