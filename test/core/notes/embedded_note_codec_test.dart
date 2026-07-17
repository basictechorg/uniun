import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';

import '../../_helpers/fixtures.dart';

/// Covers: EmbeddedNoteCodec — canonical snapshot shape (tag order,
/// created_at seconds, id/sig reuse) and verifyAndSanitize's blank-on-failure
/// contract for the embed-by-value share path.
void main() {
  group('snapshotMapFromEntity', () {
    test('rebuilds the wire form with the original id/sig, seconds '
        'timestamp, and canonical tag order', () {
      final note = aNote(
        id: 'orig-id',
        sig: 'orig-sig',
        authorPubkey: kAlicePub,
        content: 'the original',
        created: DateTime.fromMillisecondsSinceEpoch(1720000000 * 1000),
        rootEventId: 'root-id',
        replyToEventId: 'parent-id',
        eTagRefs: ['root-id', 'parent-id', 'mention-id'],
        pTagRefs: [kBobPub],
        tTags: ['nostr'],
      );

      final map = EmbeddedNoteCodec.snapshotMapFromEntity(note);
      expect(map['id'], 'orig-id');
      expect(map['sig'], 'orig-sig');
      expect(map['pubkey'], kAlicePub);
      expect(map['created_at'], 1720000000);
      expect(map['kind'], 1);
      expect(map['content'], 'the original');
      expect(map['tags'], [
        ['e', 'root-id', '', 'root'],
        ['e', 'parent-id', '', 'reply'],
        ['e', 'mention-id', '', 'mention'],
        ['p', kBobPub],
        ['t', 'nostr'],
      ]);
    });

    test('encodeFromEntity → tag() produces the wire tag pair', () {
      final json = EmbeddedNoteCodec.encodeFromEntity(aNote(id: 'n-1'));
      final tag = EmbeddedNoteCodec.tag(json);
      expect(tag.first, EmbeddedNoteCodec.tagName);
      expect(jsonDecode(tag[1]), isA<Map<String, dynamic>>());
    });
  });

  group('verifyAndSanitize', () {
    String signedSnapshot({String content = 'genuine'}) {
      final event = Event.from(
        kind: 1,
        tags: const [],
        content: content,
        privkey: kTestPrivHex,
        createdAt: 1720000000,
      );
      return jsonEncode(event.toJson());
    }

    test('genuinely signed snapshot passes through byte-identical', () {
      final json = signedSnapshot();
      expect(EmbeddedNoteCodec.verifyAndSanitize(json), json);
    });

    test('tampered content blanks the sig (unverified badge path)', () {
      final map =
          jsonDecode(signedSnapshot()) as Map<String, dynamic>;
      map['content'] = 'tampered';

      final out = EmbeddedNoteCodec.verifyAndSanitize(jsonEncode(map));
      expect((jsonDecode(out) as Map<String, dynamic>)['sig'], '');
    });

    test('forged sig blanks the sig', () {
      final map = jsonDecode(signedSnapshot()) as Map<String, dynamic>;
      map['sig'] = 'f' * 128;

      final out = EmbeddedNoteCodec.verifyAndSanitize(jsonEncode(map));
      expect((jsonDecode(out) as Map<String, dynamic>)['sig'], '');
    });

    test('structurally broken JSON is returned unchanged — nothing to '
        'blank, decoder downstream rejects it', () {
      expect(EmbeddedNoteCodec.verifyAndSanitize('not json at all'),
          'not json at all');
    });

    test('valid JSON that is not an event gets its sig slot blanked', () {
      final out = EmbeddedNoteCodec.verifyAndSanitize('{"foo": 1}');
      final map = jsonDecode(out) as Map<String, dynamic>;
      expect(map['sig'], '');
      expect(map['foo'], 1);
    });
  });
}
