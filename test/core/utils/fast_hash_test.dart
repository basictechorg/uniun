import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/utils/fast_hash.dart';

/// Covers: fastHash determinism and the frozen-algorithm golden values that
/// cross-device Isar id reconciliation depends on.
void main() {
  test('empty string is the FNV-1a 64-bit offset basis (frozen golden)', () {
    expect(fastHash(''), 0xcbf29ce484222325);
  });

  test('same input always yields the same id', () {
    final first = fastHash('group-abc-123');
    for (var i = 0; i < 100; i++) {
      expect(fastHash('group-abc-123'), first);
    }
  });

  test('distinct natural keys yield distinct ids', () {
    final seen = <int>{};
    for (var i = 0; i < 1000; i++) {
      seen.add(fastHash('event-$i'));
    }
    expect(seen, hasLength(1000));
  });

  test('case matters — keys are not folded', () {
    expect(fastHash('Alice'), isNot(fastHash('alice')));
  });

  test('non-ASCII code units (emoji surrogates, RTL) hash deterministically',
      () {
    expect(fastHash('🐉مرحبا你好'), fastHash('🐉مرحبا你好'));
    expect(fastHash('🐉'), isNot(fastHash('🐊')));
  });
}
