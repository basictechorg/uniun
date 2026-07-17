import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/utils/formatters.dart';

/// Covers: formatTimeAgo tier boundaries, formatShortPubkey and
/// formatContentPreview truncation thresholds.
void main() {
  group('formatTimeAgo', () {
    test('under a minute → "now"', () {
      expect(formatTimeAgo(DateTime.now()), 'now');
      expect(
          formatTimeAgo(
              DateTime.now().subtract(const Duration(seconds: 59))),
          'now');
    });

    test('minutes tier', () {
      expect(
          formatTimeAgo(DateTime.now().subtract(const Duration(minutes: 5))),
          '5m');
      expect(
          formatTimeAgo(DateTime.now().subtract(const Duration(minutes: 59))),
          '59m');
    });

    test('hours tier', () {
      expect(formatTimeAgo(DateTime.now().subtract(const Duration(hours: 2))),
          '2h');
      expect(formatTimeAgo(DateTime.now().subtract(const Duration(hours: 23))),
          '23h');
    });

    test('days tier caps at a week', () {
      expect(formatTimeAgo(DateTime.now().subtract(const Duration(days: 3))),
          '3d');
      expect(formatTimeAgo(DateTime.now().subtract(const Duration(days: 6))),
          '6d');
    });

    test('a week or older → absolute d-MMM-yyyy date', () {
      expect(formatTimeAgo(DateTime(2024, 12, 25)), '25-Dec-2024');
      expect(formatTimeAgo(DateTime(2025, 1, 1)), '1-Jan-2025');
    });
  });

  group('formatShortPubkey', () {
    test('12 chars or fewer pass through unchanged', () {
      expect(formatShortPubkey('abcdef123456'), 'abcdef123456');
      expect(formatShortPubkey(''), '');
    });

    test('longer keys become first-8 + ellipsis', () {
      expect(formatShortPubkey('abcdef1234567'), 'abcdef12…');
      expect(formatShortPubkey('f' * 64), '${'f' * 8}…');
    });
  });

  group('formatContentPreview', () {
    test('exactly 80 chars passes through unchanged', () {
      final s = 'x' * 80;
      expect(formatContentPreview(s), s);
    });

    test('81 chars truncates to 80 + ellipsis', () {
      final out = formatContentPreview('x' * 81);
      expect(out, '${'x' * 80}…');
    });

    test('unicode content under the limit is untouched', () {
      const s = 'مرحبا 🐉 你好';
      expect(formatContentPreview(s), s);
    });
  });
}
