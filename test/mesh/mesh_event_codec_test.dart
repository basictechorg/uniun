import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import '../_helpers/mesh_test_helpers.dart';

/// Covers MeshEventCodec sign→open roundtrip, LWW-relevant fields
/// (kind/dTag/createdAt/state), and reject paths: wrong-pubkey, tampered
/// event id, bad Schnorr signature, plaintext content (missed encryption),
/// bogus JSON, missing d tag, non-addressable kind.
void main() {
  late MeshIdentity me;
  late MeshIdentity other;
  late MeshEventCodec codec;

  setUp(() {
    me = MeshIdentity.generate();
    other = MeshIdentity.generate();
    codec = me.codec;
  });

  group('happy path', () {
    test('roundtrip preserves kind, dTag, createdAt, state, content', () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'evt-abc',
        content: {
          'state': 'active',
          'savedAt': 1720000000000,
          'note': {'id': 'evt-abc', 'author': 'alice'},
        },
        createdAtSec: 1720000000,
      );

      final record = await codec.openRecord(signed);
      expect(record.kind, MeshEventKinds.savedNote);
      expect(record.dTag, 'evt-abc');
      expect(record.createdAt, 1720000000);
      expect(record.state, MeshRecordState.active);
      expect(record.content['savedAt'], 1720000000000);
      expect(record.content['note'], {'id': 'evt-abc', 'author': 'alice'});
    });

    test('roundtrip survives Unicode, emoji, and RTL content', () async {
      const tricky = '\u{1F680} \u0928\u092E\u0938\u094D\u0924\u0947 '
          '\u05E9\u05DC\u05D5\u05DD \u200F\u0645\u0631\u062D\u0628\u0627 "q\u2019s"';
      final signed = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'evt-unicode',
        content: {'state': 'active', 'note': tricky},
      );
      final record = await codec.openRecord(signed);
      expect(record.content['note'], tricky);
    });

    test('state=removed parses through', () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'evt-abc',
        content: {'state': 'removed', 'savedAt': 42},
      );
      final record = await codec.openRecord(signed);
      expect(record.state, MeshRecordState.removed);
    });

    test('unknown state defaults to active (forward-compat)', () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'evt-abc',
        content: {'state': 'suspended-later'},
      );
      final record = await codec.openRecord(signed);
      expect(record.state, MeshRecordState.active);
    });

    test('content is opaque on the wire — plaintext is not embedded', () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.blockedUser,
        dTag: 'pubkey-of-eve',
        content: {'state': 'active', 'secret': 'do-not-see-this-plaintext'},
      );
      // A different codec (no privkey) should NOT be able to grep the plaintext
      // out of the wire form.
      expect(signed, isNot(contains('do-not-see-this-plaintext')));
      // But the d tag is intentionally plaintext (needed to address the row
      // before decrypting).
      expect(signed, contains('pubkey-of-eve'));
    });

    test('signed event is a valid Nostr event that isValid() accepts',
        () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.followedNote,
        dTag: 'evt-xyz',
        content: {'state': 'active', 'followedAt': 42},
      );
      final json = jsonDecode(signed) as Map<String, dynamic>;
      final event = Event.fromJson(json, verify: false);
      expect(event.isValid(), isTrue);
      expect(event.pubkey.toLowerCase(), me.pubkey.toLowerCase());
      expect(event.kind, MeshEventKinds.followedNote);
    });
  });

  group('failure modes', () {
    test('open throws on wrong pubkey (event signed by another identity)',
        () async {
      final foreign = other.codec;
      final signed = await foreign.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'evt-abc',
        content: {'state': 'active'},
      );
      // A foreign event can't even be decrypted by us (self-DM), but the
      // pubkey check trips first. Either way, opening must throw.
      expect(
        () => codec.openRecord(signed),
        throwsA(isA<MeshCodecException>()),
      );
    });

    test('open throws on tampered id', () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'evt-abc',
        content: {'state': 'active'},
      );
      final json = jsonDecode(signed) as Map<String, dynamic>;
      json['id'] = 'f' * 64; // still hex-shaped, but wrong
      expect(
        () => codec.openRecord(jsonEncode(json)),
        throwsA(isA<MeshCodecException>()),
      );
    });

    test('open throws on tampered signature', () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'evt-abc',
        content: {'state': 'active'},
      );
      final json = jsonDecode(signed) as Map<String, dynamic>;
      json['sig'] = '0' * 128;
      expect(
        () => codec.openRecord(jsonEncode(json)),
        throwsA(isA<MeshCodecException>()),
      );
    });

    test('open throws on plaintext content (missed encryption step)',
        () async {
      // Build a manually-signed event whose content is plaintext (skips
      // NIP-44 entirely). This models an implementation bug in a peer.
      final event = Event.from(
        kind: MeshEventKinds.savedNote,
        tags: [
          ['d', 'evt-abc'],
        ],
        content: '{"state":"active"}',
        privkey: me.privkey,
      );
      expect(
        () => codec.openRecord(jsonEncode(event.toJson())),
        throwsA(isA<MeshCodecException>()),
      );
    });

    test('open throws on missing d tag', () async {
      final event = Event.from(
        kind: MeshEventKinds.savedNote,
        tags: const [],
        content: 'anything',
        privkey: me.privkey,
      );
      expect(
        () => codec.openRecord(jsonEncode(event.toJson())),
        throwsA(isA<MeshCodecException>()),
      );
    });

    test('open throws on non-JSON string input', () async {
      expect(
        () => codec.openRecord('not json'),
        throwsA(isA<MeshCodecException>()),
      );
    });

    test('open throws on empty d tag', () async {
      // Manually signed event with an empty d value.
      final event = Event.from(
        kind: MeshEventKinds.savedNote,
        tags: [
          ['d', ''],
        ],
        content: 'anything',
        privkey: me.privkey,
      );
      expect(
        () => codec.openRecord(jsonEncode(event.toJson())),
        throwsA(isA<MeshCodecException>()),
      );
    });

    test('sign rejects non-addressable (30000-39999) kinds', () async {
      expect(
        () => codec.signRecord(
          kind: 1,
          dTag: 'x',
          content: {'state': 'active'},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── Edge cases ────────────────────────────────────────────────────────

  group('unicode + emoji in body', () {
    test('roundtrip preserves multibyte content', () async {
      final signed = await codec.signRecord(
        kind: MeshEventKinds.manas,
        dTag: 'manas-1',
        content: {
          'state': 'active',
          'name': 'Manas 🧠 مَعرِفَة 中文',
        },
      );
      final record = await codec.openRecord(signed);
      expect(record.content['name'], 'Manas 🧠 مَعرِفَة 中文');
    });
  });

  group('LWW ordering', () {
    test('two records at same (kind,d), later createdAt wins by comparison',
        () async {
      final older = await codec.openRecord(
        await codec.signRecord(
          kind: MeshEventKinds.savedNote,
          dTag: 'evt-abc',
          content: {'state': 'active'},
          createdAtSec: 1720000000,
        ),
      );
      final newer = await codec.openRecord(
        await codec.signRecord(
          kind: MeshEventKinds.savedNote,
          dTag: 'evt-abc',
          content: {'state': 'removed'},
          createdAtSec: 1720000001,
        ),
      );
      expect(newer.createdAt > older.createdAt, isTrue);
      expect(newer.state, MeshRecordState.removed);
      expect(older.state, MeshRecordState.active);
    });
  });
}
