import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';
import 'package:uniun/core/theme/theme_cubit.dart';
import 'package:uniun/domain/usecases/app_settings_usecases.dart';

class _MockSetThemeMode extends Mock implements SetThemeModeUseCase {}

/// Covers: setMode emits + persists, no-op when mode already active,
/// initial state comes from constructor.
void main() {
  setUpAll(() {
    registerFallbackValue(AppThemeMode.system);
  });

  late _MockSetThemeMode setThemeMode;

  setUp(() {
    setThemeMode = _MockSetThemeMode();
    when(() => setThemeMode.call(any()))
        .thenAnswer((_) async => const Right(unit));
  });

  test('initial state is the passed-in mode', () {
    final cubit = ThemeCubit(setThemeMode, initial: AppThemeMode.dark);
    expect(cubit.state, AppThemeMode.dark);
  });

  blocTest<ThemeCubit, AppThemeMode>(
    'setMode emits the new mode and persists it',
    build: () => ThemeCubit(setThemeMode, initial: AppThemeMode.system),
    act: (c) => c.setMode(AppThemeMode.dark),
    expect: () => [AppThemeMode.dark],
    verify: (_) =>
        verify(() => setThemeMode.call(AppThemeMode.dark)).called(1),
  );

  blocTest<ThemeCubit, AppThemeMode>(
    'setMode no-ops when the mode is already active',
    build: () => ThemeCubit(setThemeMode, initial: AppThemeMode.light),
    act: (c) => c.setMode(AppThemeMode.light),
    expect: () => const <AppThemeMode>[],
    verify: (_) => verifyNever(() => setThemeMode.call(any())),
  );

  blocTest<ThemeCubit, AppThemeMode>(
    'sequential switches emit each new mode in order',
    build: () => ThemeCubit(setThemeMode, initial: AppThemeMode.system),
    act: (c) async {
      await c.setMode(AppThemeMode.light);
      await c.setMode(AppThemeMode.dark);
      await c.setMode(AppThemeMode.system);
    },
    expect: () =>
        [AppThemeMode.light, AppThemeMode.dark, AppThemeMode.system],
    verify: (_) {
      verify(() => setThemeMode.call(AppThemeMode.light)).called(1);
      verify(() => setThemeMode.call(AppThemeMode.dark)).called(1);
      verify(() => setThemeMode.call(AppThemeMode.system)).called(1);
    },
  );
}
