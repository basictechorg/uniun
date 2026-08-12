import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/generation/prompt/prompt_parts.dart';

void main() {
  group('PromptParts', () {
    test('constants have their documented literal values', () {
      expect(PromptParts.noThink, '/no_think');
      expect(PromptParts.noopSentinel, '<NOOP>');
    });

    group('collapse', () {
      test('collapses runs of whitespace (including newlines/tabs) to one space',
          () {
        expect(PromptParts.collapse('a  b\n\nc\t\td'), 'a b c d');
      });

      test('trims leading and trailing whitespace', () {
        expect(PromptParts.collapse('  hello world  '), 'hello world');
      });

      test('empty string stays empty', () {
        expect(PromptParts.collapse(''), '');
      });

      test('whitespace-only string collapses to empty', () {
        expect(PromptParts.collapse('   \n\t  '), '');
      });

      test('preserves unicode/emoji content untouched', () {
        expect(PromptParts.collapse('héllo   🌱   wörld'), 'héllo 🌱 wörld');
      });
    });

    group('isoDate', () {
      test('pads month and day to two digits', () {
        expect(PromptParts.isoDate(DateTime(2026, 3, 5)), '2026-03-05');
      });

      test('does not pad a 4-digit year further and handles double-digit '
          'month/day', () {
        expect(PromptParts.isoDate(DateTime(2026, 12, 25)), '2026-12-25');
      });
    });
  });
}
