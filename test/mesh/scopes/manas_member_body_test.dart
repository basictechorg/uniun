// Body-level roundtrip for Kind 30511 (Manas membership edge, plan §5).
// Includes explicit d-tag edge cases because that pack/parse is the sole
// authoritative encoding of `(manasId, noteId)` slot keys on the wire.

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/features/mesh/sync/bodies/manas_member_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';

void main() {
  ManasNoteLinkModel makeRow() => ManasNoteLinkModel()
    ..manasId = 'manas-1'
    ..noteId = 'ff' * 32
    ..addedAt = DateTime.fromMillisecondsSinceEpoch(1720000000000);

  group('d-tag pack/parse', () {
    test('buildDTag concatenates with a colon', () {
      expect(ManasMemberBody.buildDTag('m', 'n'), 'm:n');
    });

    test('parseDTag splits at the first colon', () {
      final parsed = ManasMemberBody.parseDTag('manas-1:${'ff' * 32}');
      expect(parsed, isNotNull);
      expect(parsed!.manasId, 'manas-1');
      expect(parsed.noteId, 'ff' * 32);
    });

    test('parseDTag rejects a tag without a colon', () {
      expect(ManasMemberBody.parseDTag('nocolonhere'), isNull);
    });

    test('parseDTag rejects an empty manasId (leading colon)', () {
      expect(ManasMemberBody.parseDTag(':note'), isNull);
    });

    test('parseDTag rejects an empty noteId (trailing colon)', () {
      expect(ManasMemberBody.parseDTag('manas:'), isNull);
    });

    test('parseDTag rejects the empty string', () {
      expect(ManasMemberBody.parseDTag(''), isNull);
    });
  });

  group('body encode/decode', () {
    test('forActive encodes state + addedAt', () {
      final body = ManasMemberBody.forActive(makeRow());
      expect(body['state'], MeshRecordState.active.wire);
      expect(body['addedAt'], 1720000000000);
    });

    test('forRemoved flips state, keeps timestamp', () {
      final body = ManasMemberBody.forRemoved(makeRow());
      expect(body['state'], MeshRecordState.removed.wire);
      expect(body['addedAt'], 1720000000000);
    });

    test('applyBody rehydrates a fresh row from the d-tag ids', () {
      final body = ManasMemberBody.forActive(makeRow());
      final row = ManasMemberBody.applyBody(
        body,
        manasId: 'manas-1',
        noteId: 'ff' * 32,
      );
      expect(row.manasId, 'manas-1');
      expect(row.noteId, 'ff' * 32);
      expect(row.addedAt.millisecondsSinceEpoch, 1720000000000);
    });

    test('applyBody preserves Isar id when merging onto an existing row', () {
      final existing = makeRow()..id = 99;
      final body = ManasMemberBody.forActive(makeRow());
      final row = ManasMemberBody.applyBody(
        body,
        manasId: 'manas-1',
        noteId: 'ff' * 32,
        existing: existing,
      );
      expect(row.id, 99);
    });

    test('applyBody defaults addedAt=0 when the body omits it', () {
      final row = ManasMemberBody.applyBody(
        <String, dynamic>{'state': 'active'},
        manasId: 'm',
        noteId: 'n',
      );
      expect(row.addedAt.millisecondsSinceEpoch, 0);
    });
  });
}
