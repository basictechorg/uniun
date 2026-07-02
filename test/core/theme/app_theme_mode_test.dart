import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';

/// Covers: enum → Flutter ThemeMode mapping, fromName parser (null, unknown,
/// each valid name).
void main() {
  group('AppThemeMode.materialThemeMode', () {
    test('system → ThemeMode.system', () {
      expect(AppThemeMode.system.materialThemeMode, ThemeMode.system);
    });
    test('light → ThemeMode.light', () {
      expect(AppThemeMode.light.materialThemeMode, ThemeMode.light);
    });
    test('dark → ThemeMode.dark', () {
      expect(AppThemeMode.dark.materialThemeMode, ThemeMode.dark);
    });
  });

  group('AppThemeMode.fromName', () {
    test('null → null (user has never picked)', () {
      expect(AppThemeMode.fromName(null), isNull);
    });

    test('unknown string → null (defensive against schema drift)', () {
      expect(AppThemeMode.fromName('sepia'), isNull);
      expect(AppThemeMode.fromName(''), isNull);
      expect(AppThemeMode.fromName('SYSTEM'), isNull); // case-sensitive
    });

    test('valid names round-trip via .name', () {
      for (final v in AppThemeMode.values) {
        expect(AppThemeMode.fromName(v.name), v);
      }
    });
  });
}
