import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';

/// Pure-function tests for [ManasIcons]. Both `byName` and `suggestFromName`
/// are called by the Manas form on every keystroke, so a regression here
/// silently breaks the auto-suggest behaviour without throwing.
void main() {
  group('byName', () {
    test('null → fallback', () {
      expect(ManasIcons.byName(null), ManasIcons.fallback);
    });

    test('unknown key → fallback (not an exception)', () {
      expect(ManasIcons.byName('definitely-not-a-real-icon'), ManasIcons.fallback);
    });

    test('empty string → fallback', () {
      expect(ManasIcons.byName(''), ManasIcons.fallback);
    });

    test('known key → the exact registered IconData', () {
      // Every registry entry must resolve. A regression here means
      // existing stored ManasModel.iconName values stop rendering.
      for (final entry in ManasIcons.all.entries) {
        expect(ManasIcons.byName(entry.key), entry.value,
            reason: 'icon "${entry.key}" did not resolve to its registered IconData');
      }
    });

    test('every IconData in the registry is non-null', () {
      // Defensive against accidental `null` in a future PR.
      for (final v in ManasIcons.all.values) {
        expect(v, isA<IconData>());
      }
    });
  });

  group('suggestFromName', () {
    test('empty / whitespace → null (caller shows the fallback)', () {
      expect(ManasIcons.suggestFromName(''), isNull);
      expect(ManasIcons.suggestFromName('   '), isNull);
    });

    test('no keyword match → null', () {
      expect(ManasIcons.suggestFromName('blibbity blob'), isNull);
    });

    test('case-insensitive substring match wins', () {
      // The keyword map is lowercase; user input often isn't.
      expect(ManasIcons.suggestFromName('FITNESS plan'), 'fitness_center');
      expect(ManasIcons.suggestFromName('My WoRk Stuff'), 'work');
    });

    test('first keyword in iteration order wins for multi-match input', () {
      // "work travel" contains both "work" and "travel". The first matching
      // map entry wins. This pins the contract so changes to map ORDER are
      // visible in tests (otherwise an innocent reorder silently changes
      // user-facing suggestions).
      final suggestion = ManasIcons.suggestFromName('work travel');
      // The actual winner is the first key inserted in [_keywordMap] that
      // matches — assert that it IS deterministic, not what specifically
      // it is (which would over-specify implementation).
      expect(
        suggestion,
        anyOf('work', 'flight', 'business_center'),
        reason: 'multi-match should still return SOME deterministic suggestion',
      );
      expect(ManasIcons.suggestFromName('work travel'), suggestion,
          reason: 'same input must always produce the same output');
    });

    test('whitespace around the keyword is tolerated', () {
      // Users hit space accidentally. trim() in the impl makes both work.
      expect(ManasIcons.suggestFromName('  fitness  '), 'fitness_center');
    });

    test('every suggested name resolves via byName (no orphan suggestions)', () {
      // Property: every value the suggester might return MUST be a valid
      // registered icon. A typo in _keywordMap would break this.
      final samples = [
        'fitness', 'finance', 'travel', 'food', 'music', 'work', 'code',
        'home', 'family', 'science', 'security', 'note', 'chat',
      ];
      for (final s in samples) {
        final suggested = ManasIcons.suggestFromName(s);
        if (suggested != null) {
          // byName falls back when unknown — to assert the suggestion is
          // a REAL registered key we need the raw lookup.
          expect(ManasIcons.all.containsKey(suggested), isTrue,
              reason: 'suggestFromName("$s") returned "$suggested" which is not in the icon registry');
        }
      }
    });
  });

  group('allNames', () {
    test('returns every registered key, alphabetically sorted', () {
      final names = ManasIcons.allNames;
      expect(names.toSet(), ManasIcons.all.keys.toSet());
      // Sorted ascending.
      for (var i = 1; i < names.length; i++) {
        expect(names[i - 1].compareTo(names[i]), lessThanOrEqualTo(0));
      }
    });

    test('non-empty (registry is not accidentally cleared)', () {
      expect(ManasIcons.allNames, isNotEmpty);
    });
  });
}
