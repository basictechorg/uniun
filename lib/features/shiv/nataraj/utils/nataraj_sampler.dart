// lib/features/shiv/nataraj/utils/nataraj_sampler.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// A sampled note-combination plus its dedup signature.
class NatarajCombo {
  final List<String> noteIds; // sorted
  final String signature;
  const NatarajCombo(this.noteIds, this.signature);
}

/// SHA-256 of the sorted, '|'-joined note ids. Order-independent so
/// {A,B} and {B,A} collide.
String natarajSignature(List<String> noteIds) {
  final sorted = [...noteIds]..sort();
  return sha256.convert(utf8.encode(sorted.join('|'))).toString();
}

/// Total number of 2- and 3-note combinations of an [n]-note pool.
int combinationSpace(int n) {
  if (n < 2) return 0;
  final pairs = n * (n - 1) ~/ 2;
  final triplets = n >= 3 ? n * (n - 1) * (n - 2) ~/ 6 : 0;
  return pairs + triplets;
}

/// Rejection-samples up to [count] combinations whose signature is not in
/// [knownSignatures], never enumerating the full space. ~2/3 pairs, ~1/3
/// triplets. Returns fewer than [count] (possibly empty) when the fresh
/// space is exhausted.
List<NatarajCombo> sampleUnseenCombos({
  required List<String> poolIds,
  required Set<String> knownSignatures,
  required int count,
  required Random random,
  int maxAttemptsPerCombo = 40,
}) {
  final out = <NatarajCombo>[];
  if (poolIds.length < 2) return out;
  final seen = <String>{...knownSignatures};
  final space = combinationSpace(poolIds.length);

  while (out.length < count && seen.length < space) {
    NatarajCombo? found;
    for (var attempt = 0; attempt < maxAttemptsPerCombo; attempt++) {
      final canTriplet = poolIds.length >= 3;
      final size = (canTriplet && random.nextDouble() > 0.66) ? 3 : 2;
      final picked = _pickDistinct(poolIds, size, random)..sort();
      final sig = natarajSignature(picked);
      if (seen.contains(sig)) continue;
      seen.add(sig);
      found = NatarajCombo(picked, sig);
      break;
    }
    if (found == null) break; // couldn't find a fresh combo in the attempt budget
    out.add(found);
  }
  return out;
}

List<String> _pickDistinct(List<String> pool, int k, Random random) {
  final idx = <int>{};
  while (idx.length < k) {
    idx.add(random.nextInt(pool.length));
  }
  return idx.map((i) => pool[i]).toList();
}
