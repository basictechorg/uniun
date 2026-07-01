import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';
import 'package:uniun/core/theme/theme_cubit.dart';
import 'package:uniun/features/settings/widgets/theme_row.dart';
import 'package:uniun/l10n/app_localizations.dart';

class _MockThemeCubit extends MockCubit<AppThemeMode> implements ThemeCubit {}

/// Covers: row shows the right label/icon for each mode, tap opens the sheet,
/// picking an option calls cubit.setMode with that mode.
void main() {
  setUpAll(() {
    registerFallbackValue(AppThemeMode.system);
  });

  late _MockThemeCubit cubit;

  setUp(() {
    cubit = _MockThemeCubit();
    when(() => cubit.setMode(any())).thenAnswer((_) async {});
  });

  Widget host() => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: BlocProvider<ThemeCubit>.value(
          value: cubit,
          child: const Scaffold(body: ThemeRow()),
        ),
      );

  testWidgets('shows the "Match system" label + auto icon in system mode',
      (t) async {
    when(() => cubit.state).thenReturn(AppThemeMode.system);
    await t.pumpWidget(host());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.settingsTheme), findsOneWidget);
    expect(find.text(l10n.settingsThemeSystem), findsOneWidget);
    expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);
  });

  testWidgets('shows the "Light" label + sun icon in light mode', (t) async {
    when(() => cubit.state).thenReturn(AppThemeMode.light);
    await t.pumpWidget(host());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.settingsThemeLight), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets('shows the "Dark" label + moon icon in dark mode', (t) async {
    when(() => cubit.state).thenReturn(AppThemeMode.dark);
    await t.pumpWidget(host());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.settingsThemeDark), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
  });

  testWidgets('tapping the row opens the theme sheet with all three options',
      (t) async {
    when(() => cubit.state).thenReturn(AppThemeMode.system);
    await t.pumpWidget(host());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await t.tap(find.text(l10n.settingsTheme));
    await t.pumpAndSettle();

    expect(find.text(l10n.settingsThemeSheetTitle), findsOneWidget);
    // Each option label surfaces inside the sheet — the row itself only shows
    // the active label, so a `findsNWidgets(2)` on the active option +
    // `findsOneWidget` on the others is what we expect.
    expect(find.text(l10n.settingsThemeSystem), findsNWidgets(2));
    expect(find.text(l10n.settingsThemeLight), findsOneWidget);
    expect(find.text(l10n.settingsThemeDark), findsOneWidget);
  });

  testWidgets('tapping "Dark" in the sheet calls cubit.setMode(dark)',
      (t) async {
    when(() => cubit.state).thenReturn(AppThemeMode.system);
    await t.pumpWidget(host());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await t.tap(find.text(l10n.settingsTheme));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.settingsThemeDark));
    await t.pumpAndSettle();

    verify(() => cubit.setMode(AppThemeMode.dark)).called(1);
  });

  testWidgets('tapping "Light" in the sheet calls cubit.setMode(light)',
      (t) async {
    when(() => cubit.state).thenReturn(AppThemeMode.dark);
    await t.pumpWidget(host());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await t.tap(find.text(l10n.settingsTheme));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.settingsThemeLight));
    await t.pumpAndSettle();

    verify(() => cubit.setMode(AppThemeMode.light)).called(1);
  });
}
