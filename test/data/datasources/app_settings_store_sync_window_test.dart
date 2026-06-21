import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recentSyncWindowDays defaults to 7 when unset', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppSettingsStore(await SharedPreferences.getInstance());
    expect(store.recentSyncWindowDays, 7);
  });

  test('recentSyncWindowDays round-trips a set value', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppSettingsStore(await SharedPreferences.getInstance());
    await store.setRecentSyncWindowDays(60);
    expect(store.recentSyncWindowDays, 60);
  });
}
