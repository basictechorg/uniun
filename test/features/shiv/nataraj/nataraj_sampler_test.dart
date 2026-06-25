import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/nataraj/utils/nataraj_sampler.dart';

/// Pure-logic tests for the Nataraj swipe-deck sampler — the rejection sampler
/// that picks 2- or 3-note combinations from the user's pool without rerunning
/// across full enumerations.
void main() {
  group('natarajSignature', () {
    test('is order-independent ({A,B} == {B,A})', () {
      expect(natarajSignature(['A', 'B']), natarajSignature(['B', 'A']));
    });

    test('differs across disjoint sets', () {
      expect(natarajSignature(['A', 'B']),
          isNot(equals(natarajSignature(['A', 'C']))));
    });

    test('differs between a pair and the triplet that contains it', () {
      expect(natarajSignature(['A', 'B']),
          isNot(equals(natarajSignature(['A', 'B', 'C']))));
    });
  });

  group('combinationSpace', () {
    test('returns 0 for pools smaller than 2', () {
      expect(combinationSpace(0), 0);
      expect(combinationSpace(1), 0);
    });

    test('pairs only when pool size is 2', () {
      // C(2,2) = 1 pair, no triplets
      expect(combinationSpace(2), 1);
    });

    test('pairs + triplets when pool size >= 3', () {
      // n=3 → C(3,2)=3 + C(3,3)=1 = 4
      expect(combinationSpace(3), 4);
      // n=5 → C(5,2)=10 + C(5,3)=10 = 20
      expect(combinationSpace(5), 20);
    });
  });

  group('sampleUnseenCombos', () {
    final rng = Random(42);

    test('returns empty when pool has fewer than 2 notes', () {
      expect(
        sampleUnseenCombos(
            poolIds: ['only'],
            knownSignatures: const {},
            count: 5,
            random: rng),
        isEmpty,
      );
    });

    test('every returned combo is fresh (signature not in knownSignatures)',
        () {
      final seen = {
        natarajSignature(['A', 'B']),
        natarajSignature(['B', 'C']),
      };
      final out = sampleUnseenCombos(
        poolIds: ['A', 'B', 'C', 'D', 'E'],
        knownSignatures: seen,
        count: 3,
        random: rng,
      );
      for (final combo in out) {
        expect(seen.contains(combo.signature), isFalse,
            reason: 'combo ${combo.noteIds} collided with a known signature');
      }
    });

    test('combos do not repeat within a single call', () {
      final out = sampleUnseenCombos(
        poolIds: ['A', 'B', 'C', 'D', 'E'],
        knownSignatures: const {},
        count: 8,
        random: rng,
      );
      final sigs = out.map((c) => c.signature).toSet();
      expect(sigs.length, out.length);
    });

    test('returns at most the full unseen space — never exceeds it', () {
      // n=2 → 1 possible combo total. Asking for 5 returns just that 1.
      final out = sampleUnseenCombos(
        poolIds: ['A', 'B'],
        knownSignatures: const {},
        count: 5,
        random: rng,
      );
      expect(out.length, 1);
      expect(out.single.noteIds, ['A', 'B']);
    });

    test('honors count when the fresh space is large enough', () {
      final out = sampleUnseenCombos(
        poolIds: List.generate(8, (i) => 'n$i'),
        knownSignatures: const {},
        count: 4,
        random: rng,
      );
      expect(out.length, 4);
    });

    test('produces a mix of pair and triplet sizes over many samples', () {
      final out = sampleUnseenCombos(
        poolIds: List.generate(10, (i) => 'n$i'),
        knownSignatures: const {},
        count: 60,
        random: Random(1),
      );
      final pairs = out.where((c) => c.noteIds.length == 2).length;
      final triplets = out.where((c) => c.noteIds.length == 3).length;
      // Implementation tilts ~2:1 pairs:triplets; assert both are non-trivial
      // without pinning a specific ratio (sampler is randomized by design).
      expect(pairs, greaterThan(0));
      expect(triplets, greaterThan(0));
    });
  });
}
