import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';
import 'package:uniun/domain/repositories/app_settings_repository.dart';
import 'package:uniun/domain/usecases/app_settings_usecases.dart';

class _MockAppSettingsRepository extends Mock
    implements AppSettingsRepository {}

void main() {
  late _MockAppSettingsRepository repo;

  setUp(() {
    repo = _MockAppSettingsRepository();
  });

  test('GetNatarajCoachSeenUseCase delegates', () async {
    when(() => repo.getNatarajCoachSeen()).thenAnswer((_) async => const Right(true));

    final result = await GetNatarajCoachSeenUseCase(repo).call();

    expect(result, const Right<Failure, bool>(true));
  });

  test('SetNatarajCoachSeenUseCase forwards the flag', () async {
    when(() => repo.setNatarajCoachSeen(true)).thenAnswer((_) async => const Right(unit));

    await SetNatarajCoachSeenUseCase(repo).call(true);

    verify(() => repo.setNatarajCoachSeen(true)).called(1);
  });

  test('GetAutoDeleteOldNotesDaysUseCase delegates', () async {
    when(() => repo.getAutoDeleteOldNotesDays()).thenAnswer((_) async => const Right(7));

    final result = await GetAutoDeleteOldNotesDaysUseCase(repo).call();

    expect(result, const Right<Failure, int?>(7));
  });

  test('SetAutoDeleteOldNotesDaysUseCase forwards null to disable', () async {
    when(() => repo.setAutoDeleteOldNotesDays(null)).thenAnswer((_) async => const Right(unit));

    await SetAutoDeleteOldNotesDaysUseCase(repo).call(null);

    verify(() => repo.setAutoDeleteOldNotesDays(null)).called(1);
  });

  test('GetRecentSyncWindowDaysUseCase delegates', () async {
    when(() => repo.getRecentSyncWindowDays()).thenAnswer((_) async => const Right(7));

    final result = await GetRecentSyncWindowDaysUseCase(repo).call();

    expect(result, const Right<Failure, int>(7));
  });

  test('SetRecentSyncWindowDaysUseCase forwards the value', () async {
    when(() => repo.setRecentSyncWindowDays(14)).thenAnswer((_) async => const Right(unit));

    await SetRecentSyncWindowDaysUseCase(repo).call(14);

    verify(() => repo.setRecentSyncWindowDays(14)).called(1);
  });

  test('SetAppLocaleUseCase forwards a locale code', () async {
    when(() => repo.setLocaleCode('hi')).thenAnswer((_) async => const Right(unit));

    await SetAppLocaleUseCase(repo).call('hi');

    verify(() => repo.setLocaleCode('hi')).called(1);
  });

  test('SetAppLocaleUseCase forwards null to clear the override', () async {
    when(() => repo.setLocaleCode(null)).thenAnswer((_) async => const Right(unit));

    await SetAppLocaleUseCase(repo).call(null);

    verify(() => repo.setLocaleCode(null)).called(1);
  });

  test('SetThemeModeUseCase forwards the mode', () async {
    when(() => repo.setThemeMode(AppThemeMode.dark)).thenAnswer((_) async => const Right(unit));

    await SetThemeModeUseCase(repo).call(AppThemeMode.dark);

    verify(() => repo.setThemeMode(AppThemeMode.dark)).called(1);
  });
}
