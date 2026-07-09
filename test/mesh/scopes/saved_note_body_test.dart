// Round-trip tests for [SavedNoteBody] — the plaintext body shape carried
// inside a Kind-30500 mesh event. Pure Dart, no plugin channels, no Isar.
// Verifies every field on the source row survives forActive → applyBody
// (and forRemoved → applyBody) unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/features/mesh/sync/bodies/saved_note_body.dart';

void main() {
  test('forActive → applyBody preserves every column', () {
    final att = MediaAttachment()
      ..sha256 = 'sha-a'
      ..mime = 'image/jpeg'
      ..sizeBytes = 1234
      ..url = 'https://cdn/x.jpg'
      ..width = 640
      ..height = 480
      ..blurhash = 'LEHV6nWB'
      ..filename = 'x.jpg';
    final src = SavedNoteModel()
      ..eventId = 'ev-1'
      ..sig = 'sig-1'
      ..authorPubkey = 'pk-1'
      ..content = 'hello 🚀'
      ..type = NoteType.image
      ..eTagRefs = const ['e-root', 'e-reply']
      ..rootEventId = 'e-root'
      ..replyToEventId = 'e-parent'
      ..pTagRefs = const ['p-1', 'p-2']
      ..tTags = const ['#tag']
      ..created = DateTime.fromMillisecondsSinceEpoch(1720000000000)
      ..savedAt = DateTime.fromMillisecondsSinceEpoch(1720000100000)
      ..sourceGroupId = 'chan-x'
      ..sourcePrivateGroupId = null
      ..embeddedNoteJson = '{"quoted":true}'
      ..attachments = [att];

    final body = SavedNoteBody.forActive(src);
    expect(body['state'], 'active');

    final round = SavedNoteBody.applyBody(body, eventId: 'ev-1');
    expect(round.eventId, 'ev-1');
    expect(round.sig, 'sig-1');
    expect(round.authorPubkey, 'pk-1');
    expect(round.content, 'hello 🚀');
    expect(round.type, NoteType.image);
    expect(round.eTagRefs, ['e-root', 'e-reply']);
    expect(round.rootEventId, 'e-root');
    expect(round.replyToEventId, 'e-parent');
    expect(round.pTagRefs, ['p-1', 'p-2']);
    expect(round.tTags, ['#tag']);
    expect(round.created.millisecondsSinceEpoch, 1720000000000);
    expect(round.savedAt.millisecondsSinceEpoch, 1720000100000);
    expect(round.sourceGroupId, 'chan-x');
    expect(round.sourcePrivateGroupId, isNull);
    expect(round.embeddedNoteJson, '{"quoted":true}');
    expect(round.attachments.single.sha256, 'sha-a');
    expect(round.attachments.single.mime, 'image/jpeg');
    expect(round.attachments.single.sizeBytes, 1234);
    expect(round.attachments.single.url, 'https://cdn/x.jpg');
    expect(round.attachments.single.width, 640);
    expect(round.attachments.single.height, 480);
    expect(round.attachments.single.blurhash, 'LEHV6nWB');
    expect(round.attachments.single.filename, 'x.jpg');
  });

  test('forRemoved emits state=removed but carries full note shape', () {
    // Plan §5a: the tombstone body must carry the full shape so a peer that
    // only ever sees the removal (never the active event) can still populate
    // every column. The receiver decides visibility from `removedAt`, not
    // from body contents.
    final src = SavedNoteModel()
      ..eventId = 'ev-r'
      ..sig = 'sig-r'
      ..authorPubkey = 'pk-r'
      ..content = 'gone'
      ..type = NoteType.text
      ..eTagRefs = const []
      ..pTagRefs = const []
      ..tTags = const []
      ..created = DateTime.fromMillisecondsSinceEpoch(1720000000000)
      ..savedAt = DateTime.fromMillisecondsSinceEpoch(1720000200000);

    final body = SavedNoteBody.forRemoved(src);
    expect(body['state'], 'removed');

    final round = SavedNoteBody.applyBody(body, eventId: 'ev-r');
    expect(round.content, 'gone');
    expect(round.savedAt.millisecondsSinceEpoch, 1720000200000);
  });

  test('applyBody updates an existing row in place', () {
    final existing = SavedNoteModel()
      ..eventId = 'ev-x'
      ..sig = 'old-sig'
      ..authorPubkey = 'pk'
      ..content = 'old'
      ..type = NoteType.text
      ..eTagRefs = const []
      ..pTagRefs = const []
      ..tTags = const []
      ..created = DateTime.fromMillisecondsSinceEpoch(0)
      ..savedAt = DateTime.fromMillisecondsSinceEpoch(0);

    final src = SavedNoteModel()
      ..eventId = 'ev-x'
      ..sig = 'new-sig'
      ..authorPubkey = 'pk'
      ..content = 'new'
      ..type = NoteType.text
      ..eTagRefs = const []
      ..pTagRefs = const []
      ..tTags = const []
      ..created = DateTime.fromMillisecondsSinceEpoch(1720000000000)
      ..savedAt = DateTime.fromMillisecondsSinceEpoch(1720000300000);

    final round = SavedNoteBody.applyBody(
      SavedNoteBody.forActive(src),
      eventId: 'ev-x',
      existing: existing,
    );
    // Same object identity — Isar's `put` uses this instance's id.
    expect(identical(round, existing), isTrue);
    expect(round.sig, 'new-sig');
    expect(round.content, 'new');
  });

  test('applyBody throws on missing note field', () {
    // Malformed body should NOT silently succeed — the scope's caller relies
    // on FormatException to log-and-drop.
    expect(
      () => SavedNoteBody.applyBody(<String, dynamic>{
        'state': 'active',
        'savedAt': 0,
        // no 'note' key
      }, eventId: 'x'),
      throwsA(isA<FormatException>()),
    );
  });

  test('applyBody defaults unknown type to text (defense against bad senders)',
      () {
    final round = SavedNoteBody.applyBody(<String, dynamic>{
      'state': 'active',
      'savedAt': 0,
      'note': <String, dynamic>{
        'id': 'x',
        'sig': '',
        'pubkey': '',
        'content': 'c',
        'type': 'not-a-real-type',
        'eTagRefs': [],
        'pTagRefs': [],
        'tTags': [],
        'created': 0,
        'attachments': [],
      },
    }, eventId: 'x');
    expect(round.type, NoteType.text);
  });

  test('applyBody tolerates missing optional fields on the wire', () {
    final round = SavedNoteBody.applyBody(<String, dynamic>{
      'state': 'active',
      'savedAt': 0,
      // no sourceGroupId, no sourcePrivateGroupId, no embeddedNoteJson
      'note': <String, dynamic>{
        'id': 'x',
        'sig': '',
        'pubkey': '',
        'content': 'c',
        'type': 'text',
        'eTagRefs': [],
        'pTagRefs': [],
        'tTags': [],
        'created': 0,
        // no attachments
      },
    }, eventId: 'x');
    expect(round.sourceGroupId, isNull);
    expect(round.sourcePrivateGroupId, isNull);
    expect(round.embeddedNoteJson, isNull);
    expect(round.attachments, isEmpty);
  });
}
