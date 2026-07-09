import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/repositories/app_settings_repository_impl.dart';

/// Covers: AppSettingsRepositoryImpl over a real AppSettingsStore —
/// natarajCoachSeen, autoDeleteOldNotesDays null/boundary sanitization,
/// recentSyncWindowDays default, localeCode set/clear, themeMode set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettingsStore store;
  late AppSettingsRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppSettingsStore(await SharedPreferences.getInstance());
    repo = AppSettingsRepositoryImpl(store);
  });

  group('natarajCoachSeen', () {
    test('defaults to false on a fresh install', () async {
      final r = await repo.getNatarajCoachSeen();
      expect(r.getOrElse(() => true), isFalse);
    });

    test('set → get round-trips true', () async {
      expect((await repo.setNatarajCoachSeen(true)).isRight(), isTrue);
      expect((await repo.getNatarajCoachSeen()).getOrElse(() => false),
          isTrue);
    });

    test('can be flipped back to false', () async {
      await repo.setNatarajCoachSeen(true);
      await repo.setNatarajCoachSeen(false);
      expect((await repo.getNatarajCoachSeen()).getOrElse(() => true),
          isFalse);
    });
  });

  group('autoDeleteOldNotesDays', () {
    test('defaults to null (auto-delete disabled)', () async {
      final r = await repo.getAutoDeleteOldNotesDays();
      expect(r.getOrElse(() => -1), isNull);
    });

    test('set → get round-trips a positive value', () async {
      await repo.setAutoDeleteOldNotesDays(30);
      expect((await repo.getAutoDeleteOldNotesDays()).getOrElse(() => null),
          30);
    });

    test('setting null clears the value', () async {
      await repo.setAutoDeleteOldNotesDays(30);
      await repo.setAutoDeleteOldNotesDays(null);
      expect((await repo.getAutoDeleteOldNotesDays()).getOrElse(() => -1),
          isNull);
    });

    test('zero is treated as disabled (cleared)', () async {
      await repo.setAutoDeleteOldNotesDays(30);
      await repo.setAutoDeleteOldNotesDays(0);
      expect((await repo.getAutoDeleteOldNotesDays()).getOrElse(() => -1),
          isNull);
    });

    test('negative is treated as disabled (cleared)', () async {
      await repo.setAutoDeleteOldNotesDays(-5);
      expect((await repo.getAutoDeleteOldNotesDays()).getOrElse(() => -1),
          isNull);
    });

    test('boundary: 1 day is a valid setting', () async {
      await repo.setAutoDeleteOldNotesDays(1);
      expect((await repo.getAutoDeleteOldNotesDays()).getOrElse(() => null),
          1);
    });
  });

  group('recentSyncWindowDays', () {
    test('defaults to 7 when never set', () async {
      final r = await repo.getRecentSyncWindowDays();
      expect(r.getOrElse(() => -1), 7);
    });

    test('set → get round-trips', () async {
      await repo.setRecentSyncWindowDays(30);
      expect((await repo.getRecentSyncWindowDays()).getOrElse(() => -1), 30);
    });

    test('non-positive stored value falls back to the default 7', () async {
      await repo.setRecentSyncWindowDays(0);
      expect((await repo.getRecentSyncWindowDays()).getOrElse(() => -1), 7);
    });
  });

  group('localeCode', () {
    test('set persists to the store', () async {
      expect((await repo.setLocaleCode('hi')).isRight(), isTrue);
      expect(store.localeCode, 'hi');
    });

    test('setting null clears the explicit choice (system locale)', () async {
      await repo.setLocaleCode('hi');
      expect((await repo.setLocaleCode(null)).isRight(), isTrue);
      expect(store.localeCode, isNull);
    });
  });

  group('themeMode', () {
    test('set persists every enum value', () async {
      for (final mode in AppThemeMode.values) {
        expect((await repo.setThemeMode(mode)).isRight(), isTrue,
            reason: 'mode $mode');
        expect(store.themeMode, mode);
      }
    });

    test('unset store reads back null (treated as system upstream)', () {
      expect(store.themeMode, isNull);
    });
  });
}
