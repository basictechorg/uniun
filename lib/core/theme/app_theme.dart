import 'package:flutter/material.dart';

/// UNIUN design system colors — sourced directly from the design HTML.
///
/// PRIMARY: #0075F2 — the single brand blue used on all buttons, active states,
/// icons, and text highlights. Change only this const to retheme the entire app.
abstract class AppColors {
  static const primary = Color(0xFF0075f2);
  static const primaryContainer = Color(0xFF55a7ff);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFFEFCFF);

  static const secondary = Color(0xFF475F89);
  static const secondaryContainer = Color(0xFFB8CFFF);
  static const onSecondary = Color(0xFFFFFFFF);
  static const onSecondaryContainer = Color(0xFF415882);

  static const tertiary = Color(0xFF934700);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFB85A00);
  static const onTertiaryContainer = Color(0xFFFFFBFF);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF414753);

  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF8F9FB);
  static const surfaceContainer = Color(0xFFEDEEF0);
  static const surfaceContainerHigh = Color(0xFFE7E8EA);
  static const surfaceContainerHighest = Color(0xFFE1E2E4);

  static const outline = Color(0xFF727785);
  static const outlineVariant = Color(0xFFC1C6D5);
  static const iconInactive = Color(0xFFcaccce);

  static const inverseSurface = Color(0xFF2E3132);
  static const inverseOnSurface = Color(0xFFF0F1F3);
  static const inversePrimary = Color(0xFFABC7FF);

  static const graphSaved = Color(0xFF0075f2);
  static const graphOwn = Color(0xFF059669);
  static const graphDraft = Color(0xFFD97706);
}

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

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        textTheme: AppTextStyles.textTheme,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          tertiary: AppColors.tertiary,
          onTertiary: AppColors.onTertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          onTertiaryContainer: AppColors.onTertiaryContainer,
          error: AppColors.error,
          onError: AppColors.onError,
          errorContainer: AppColors.errorContainer,
          onErrorContainer: AppColors.onErrorContainer,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
          inverseSurface: AppColors.inverseSurface,
          onInverseSurface: AppColors.inverseOnSurface,
          inversePrimary: AppColors.inversePrimary,
        ),
        scaffoldBackgroundColor: AppColors.surfaceContainerLowest,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
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
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: AppColors.outline),
        ),
      );
}
