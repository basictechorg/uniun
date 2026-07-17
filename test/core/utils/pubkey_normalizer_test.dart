import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/utils/pubkey_normalizer.dart';

import '../../_helpers/fixtures.dart';

/// Covers: normalizeNostrPubkey canonicalization (npub decode, case fold,
/// trim) and rejection of malformed input.
void main() {
  test('lowercase 64-char hex passes through unchanged', () {
    expect(normalizeNostrPubkey(kSampleTargetPubkeyHex),
        kSampleTargetPubkeyHex);
  });

  test('uppercase hex folds to lowercase', () {
    expect(normalizeNostrPubkey(kSampleTargetPubkeyHex.toUpperCase()),
        kSampleTargetPubkeyHex);
  });

  test('npub decodes to the underlying hex', () {
    final npub = Nip19.encodePubkey(kSampleTargetPubkeyHex);
    expect(normalizeNostrPubkey(npub), kSampleTargetPubkeyHex);
  });

  test('surrounding whitespace is trimmed before decoding', () {
    expect(normalizeNostrPubkey('  $kSampleTargetPubkeyHex\n'),
        kSampleTargetPubkeyHex);
    expect(
        normalizeNostrPubkey(
            '\t${Nip19.encodePubkey(kSampleTargetPubkeyHex)} '),
        kSampleTargetPubkeyHex);
  });

  test('wrong length hex is rejected', () {
    expect(() => normalizeNostrPubkey('a' * 63), throwsFormatException);
    expect(() => normalizeNostrPubkey('a' * 65), throwsFormatException);
    expect(() => normalizeNostrPubkey(''), throwsFormatException);
  });

  test('non-hex characters are rejected', () {
    expect(() => normalizeNostrPubkey('g' * 64), throwsFormatException);
    expect(() => normalizeNostrPubkey('not-a-pubkey'), throwsFormatException);
  });

  test('corrupt npub (bad checksum) throws instead of returning garbage', () {
    expect(() => normalizeNostrPubkey('npub1invalidinvalidinvalid'),
        throwsA(anything));
  });
}
