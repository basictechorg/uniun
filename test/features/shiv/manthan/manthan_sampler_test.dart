// test/features/shiv/manthan/manthan_sampler_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/manthan/utils/manthan_sampler.dart';

void main() {
  test('signature is order-independent', () {
    expect(manthanSignature(['a', 'b']), manthanSignature(['b', 'a']));
    expect(manthanSignature(['a', 'b']), isNot(manthanSignature(['a', 'c'])));
  });

  test('combinationSpace counts pairs + triplets', () {
    expect(combinationSpace(1), 0);
    expect(combinationSpace(2), 1); // C(2,2)
    expect(combinationSpace(3), 4); // C(3,2)=3 + C(3,3)=1
    expect(combinationSpace(4), 10); // C(4,2)=6 + C(4,3)=4
  });

  test('returns distinct fresh combos for a larger pool', () {
    final combos = sampleUnseenCombos(
      poolIds: ['a', 'b', 'c', 'd'],
      knownSignatures: {},
      count: 3,
      random: Random(1),
    );
    expect(combos.length, 3);
    expect(combos.map((c) => c.signature).toSet().length, 3);
    for (final c in combos) {
      expect(c.noteIds.length, anyOf(2, 3));
    }
  });

  test('skips known signatures and returns empty when exhausted', () {
    final known = {manthanSignature(['a', 'b'])};
    final combos = sampleUnseenCombos(
      poolIds: ['a', 'b'],
      knownSignatures: known,
      count: 5,
      random: Random(1),
    );
    expect(combos, isEmpty); // only combo {a,b} is already known
  });

  test('never reuses a signature within one batch', () {
    final combos = sampleUnseenCombos(
      poolIds: ['a', 'b', 'c'],
      knownSignatures: {},
      count: 4, // space is 4 (3 pairs + 1 triplet)
      random: Random(7),
    );
    expect(combos.map((c) => c.signature).toSet().length, combos.length);
  });
}
