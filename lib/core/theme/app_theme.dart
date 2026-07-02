import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_custom_colors.dart';

/// UNIUN typography scale. Used via `Theme.of(context).textTheme.<role>` so a
/// future font swap (or weight tweak) lands in one place.
abstract class AppTextStyles {
  static const TextTheme textTheme = TextTheme(
    displayLarge:
        TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2),
    displayMedium:
        TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    headlineLarge:
        TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
    headlineMedium:
        TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
    titleLarge:
        TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35),
    titleMedium:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall:
        TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
    labelLarge:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
    labelMedium:
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
    labelSmall:
        TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.4),
  );
}

/// Light-mode ColorScheme values. Sourced from the design HTML.
class _LightColorScheme {
  static const primary = Color(0xFF0075F2);
  static const primaryContainer = Color(0xFF55A7FF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFFEFCFF);
  static const secondary = Color(0xFF475F89);
  static const secondaryContainer = Color(0xFFB8CFFF);
  static const onSecondary = Color(0xFFFFFFFF);
  static const onSecondaryContainer = Color(0xFF415882);
  static const tertiary = Color(0xFF934700);
  static const tertiaryContainer = Color(0xFFB85A00);
  static const onTertiary = Color(0xFFFFFFFF);
  static const onTertiaryContainer = Color(0xFFFFFBFF);
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF414753);
  static const outline = Color(0xFF727785);
  static const outlineVariant = Color(0xFFC1C6D5);
  static const inverseSurface = Color(0xFF2E3132);
  static const inverseOnSurface = Color(0xFFF0F1F3);
  static const inversePrimary = Color(0xFFABC7FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF8F9FB);
  static const surfaceContainer = Color(0xFFEDEEF0);
  static const surfaceContainerHigh = Color(0xFFE7E8EA);
  static const surfaceContainerHighest = Color(0xFFE1E2E4);
}

/// Dark-mode ColorScheme values — see docs/DESIGN.md dark palette table.
class _DarkColorScheme {
  static const primary = Color(0xFF5EA0FF);
  static const primaryContainer = Color(0xFF003E80);
  static const onPrimary = Color(0xFF002E64);
  static const onPrimaryContainer = Color(0xFFD3E3FF);
  static const secondary = Color(0xFFB0C5F2);
  static const secondaryContainer = Color(0xFF2E4570);
  static const onSecondary = Color(0xFF182B4E);
  static const onSecondaryContainer = Color(0xFFD3E1FF);
  static const tertiary = Color(0xFFFFB68F);
  static const tertiaryContainer = Color(0xFF6E3300);
  static const onTertiary = Color(0xFF4A1F00);
  static const onTertiaryContainer = Color(0xFFFFDBC8);
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);
  static const surface = Color(0xFF101317);
  static const onSurface = Color(0xFFE1E2E4);
  static const onSurfaceVariant = Color(0xFFC4C7CE);
  static const outline = Color(0xFF8B909D);
  static const outlineVariant = Color(0xFF40454E);
  static const inverseSurface = Color(0xFFE1E2E4);
  static const inverseOnSurface = Color(0xFF191C1E);
  static const inversePrimary = Color(0xFF0075F2);
  static const surfaceContainerLowest = Color(0xFF0B0E10);
  static const surfaceContainerLow = Color(0xFF171B1E);
  static const surfaceContainer = Color(0xFF1D2124);
  static const surfaceContainerHigh = Color(0xFF272B2E);
  static const surfaceContainerHighest = Color(0xFF32363A);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: AppTextStyles.textTheme,
        extensions: const [AppCustomColors.light],
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: _LightColorScheme.primary,
          onPrimary: _LightColorScheme.onPrimary,
          primaryContainer: _LightColorScheme.primaryContainer,
          onPrimaryContainer: _LightColorScheme.onPrimaryContainer,
          secondary: _LightColorScheme.secondary,
          onSecondary: _LightColorScheme.onSecondary,
          secondaryContainer: _LightColorScheme.secondaryContainer,
          onSecondaryContainer: _LightColorScheme.onSecondaryContainer,
          tertiary: _LightColorScheme.tertiary,
          onTertiary: _LightColorScheme.onTertiary,
          tertiaryContainer: _LightColorScheme.tertiaryContainer,
          onTertiaryContainer: _LightColorScheme.onTertiaryContainer,
          error: _LightColorScheme.error,
          onError: _LightColorScheme.onError,
          errorContainer: _LightColorScheme.errorContainer,
          onErrorContainer: _LightColorScheme.onErrorContainer,
          surface: _LightColorScheme.surface,
          onSurface: _LightColorScheme.onSurface,
          onSurfaceVariant: _LightColorScheme.onSurfaceVariant,
          surfaceContainerLowest: _LightColorScheme.surfaceContainerLowest,
          surfaceContainerLow: _LightColorScheme.surfaceContainerLow,
          surfaceContainer: _LightColorScheme.surfaceContainer,
          surfaceContainerHigh: _LightColorScheme.surfaceContainerHigh,
          surfaceContainerHighest: _LightColorScheme.surfaceContainerHighest,
          outline: _LightColorScheme.outline,
          outlineVariant: _LightColorScheme.outlineVariant,
          inverseSurface: _LightColorScheme.inverseSurface,
          onInverseSurface: _LightColorScheme.inverseOnSurface,
          inversePrimary: _LightColorScheme.inversePrimary,
        ),
        scaffoldBackgroundColor: _LightColorScheme.surfaceContainerLowest,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _LightColorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _LightColorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: _LightColorScheme.outline),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: AppTextStyles.textTheme,
        extensions: const [AppCustomColors.dark],
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: _DarkColorScheme.primary,
          onPrimary: _DarkColorScheme.onPrimary,
          primaryContainer: _DarkColorScheme.primaryContainer,
          onPrimaryContainer: _DarkColorScheme.onPrimaryContainer,
          secondary: _DarkColorScheme.secondary,
          onSecondary: _DarkColorScheme.onSecondary,
          secondaryContainer: _DarkColorScheme.secondaryContainer,
          onSecondaryContainer: _DarkColorScheme.onSecondaryContainer,
          tertiary: _DarkColorScheme.tertiary,
          onTertiary: _DarkColorScheme.onTertiary,
          tertiaryContainer: _DarkColorScheme.tertiaryContainer,
          onTertiaryContainer: _DarkColorScheme.onTertiaryContainer,
          error: _DarkColorScheme.error,
          onError: _DarkColorScheme.onError,
          errorContainer: _DarkColorScheme.errorContainer,
          onErrorContainer: _DarkColorScheme.onErrorContainer,
          surface: _DarkColorScheme.surface,
          onSurface: _DarkColorScheme.onSurface,
          onSurfaceVariant: _DarkColorScheme.onSurfaceVariant,
          surfaceContainerLowest: _DarkColorScheme.surfaceContainerLowest,
          surfaceContainerLow: _DarkColorScheme.surfaceContainerLow,
          surfaceContainer: _DarkColorScheme.surfaceContainer,
          surfaceContainerHigh: _DarkColorScheme.surfaceContainerHigh,
          surfaceContainerHighest: _DarkColorScheme.surfaceContainerHighest,
          outline: _DarkColorScheme.outline,
          outlineVariant: _DarkColorScheme.outlineVariant,
          inverseSurface: _DarkColorScheme.inverseSurface,
          onInverseSurface: _DarkColorScheme.inverseOnSurface,
          inversePrimary: _DarkColorScheme.inversePrimary,
        ),
        scaffoldBackgroundColor: _DarkColorScheme.surfaceContainerLowest,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _DarkColorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _DarkColorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: _DarkColorScheme.outline),
        ),
      );
}
