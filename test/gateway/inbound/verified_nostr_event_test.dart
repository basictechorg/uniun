import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../_helpers/fixtures.dart';

/// Covers: inbound Nostr event verification and malformed tag rejection.
void main() {
  test('accepts a signed event and normalizes string tags', () {
    final signed = Event.from(
      kind: 1,
      tags: const [
        ['t', 'nostr'],
      ],
      content: 'hello',
      privkey: kTestPrivHex,
    ).toJson();

    final event = const NostrEventVerifier().verify(signed);

    expect(event, isNotNull);
    expect(event!.id, signed['id']);
    expect(event.pubkey, signed['pubkey']);
    expect(event.tags, const [
      ['t', 'nostr'],
    ]);
  });

  test('rejects malformed tags before handlers see them', () {
    final signed = Event.from(
      kind: 1,
      tags: const [
        ['t', 'nostr'],
      ],
      content: 'hello',
      privkey: kTestPrivHex,
    ).toJson();

    signed['tags'] = [
      ['e', 42],
    ];

    expect(const NostrEventVerifier().verify(signed), isNull);
  });

  test('rejects id or signature mismatches', () {
    final signed = Event.from(
      kind: 1,
      tags: const [],
      content: 'hello',
      privkey: kTestPrivHex,
    ).toJson();

    signed['content'] = 'tampered';

    expect(const NostrEventVerifier().verify(signed), isNull);
  });
}
