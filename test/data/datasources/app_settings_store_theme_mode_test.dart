import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';

/// Covers: themeMode getter returns null when unset, round-trips each enum
/// value, clears when passed null, ignores unknown stored strings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('themeMode is null when never set', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppSettingsStore(await SharedPreferences.getInstance());
    expect(store.themeMode, isNull);
  });

  test('themeMode round-trips each AppThemeMode value', () async {
    for (final v in AppThemeMode.values) {
      SharedPreferences.setMockInitialValues({});
      final store = AppSettingsStore(await SharedPreferences.getInstance());
      await store.setThemeMode(v);
      expect(store.themeMode, v);
    }
  });

  test('setThemeMode(null) clears any previously-stored value', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppSettingsStore(await SharedPreferences.getInstance());
    await store.setThemeMode(AppThemeMode.dark);
    expect(store.themeMode, AppThemeMode.dark);
    await store.setThemeMode(null);
    expect(store.themeMode, isNull);
  });

  test('themeMode returns null when the stored string is unknown', () async {
    // Simulates a downgrade / schema drift: a version that wrote a mode we no
    // longer recognise shouldn't crash us — treat as "never picked".
    SharedPreferences.setMockInitialValues({
      'app_settings.theme_mode': 'sepia',
    });
    final store = AppSettingsStore(await SharedPreferences.getInstance());
    expect(store.themeMode, isNull);
  });
}
