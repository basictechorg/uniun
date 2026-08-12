import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind1_note_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../../_helpers/isar_test_harness.dart';

const _kAlice = 'alice-pub-hex';
const _kSelf = 'self-pub-hex';

VerifiedNostrEvent _event({
  required String id,
  String pubkey = _kAlice,
  int createdAt = 1_700_000_000,
  List<List<String>> tags = const [],
  String content = 'hello',
  String sig = 'sig',
}) {
  return VerifiedNostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 1,
    tags: tags,
    content: content,
    sig: sig,
    raw: {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': 1,
      'tags': tags,
      'content': content,
      'sig': sig,
    },
  );
}

/// Covers: Kind1NoteHandler's tag parsing (root/reply markers, mentions,
/// p/t tags, embedded-note snapshot verification), idempotent insert
/// (existing row is left alone except raw-json backfill), unread-row
/// insertion gated on non-own authorship, reply-edge creation excluding the
/// root, and the catch-all write-failure swallow.
void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('declares kind 1', () {
    expect(Kind1NoteHandler(activePubkey: _kSelf).kinds, {1});
  });

  test('persists a fresh note with full tag parsing', () async {
    final handler = Kind1NoteHandler(activePubkey: _kSelf);
    await handler.handle(
      _event(
        id: 'n1',
        tags: [
          ['e', 'root-1', '', 'root'],
          ['e', 'parent-1', '', 'reply'],
          ['e', 'mention-1', '', 'mention'],
          ['p', 'someone'],
          ['t', 'topic'],
        ],
      ),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('n1').findFirst();
    expect(row, isNotNull);
    expect(row!.rootEventId, 'root-1');
    expect(row.replyToEventId, 'parent-1');
    expect(row.eTagRefs, ['root-1', 'parent-1', 'mention-1']);
    expect(row.pTagRefs, ['someone']);
    expect(row.tTags, ['topic']);
    expect(row.authorPubkey, _kAlice);
    expect(row.rawEventJson, isNotNull);
  });

  test('inserts an unread row for a note from someone else', () async {
    final handler = Kind1NoteHandler(activePubkey: _kSelf);
    await handler.handle(_event(id: 'n1'), isar);

    final unread =
        await isar.unreadNoteModels.where().eventIdEqualTo('n1').findFirst();
    expect(unread, isNotNull);
  });

  test('no unread row for the active user\'s own note', () async {
    final handler = Kind1NoteHandler(activePubkey: _kAlice);
    await handler.handle(_event(id: 'n1', pubkey: _kAlice), isar);

    final unread =
        await isar.unreadNoteModels.where().eventIdEqualTo('n1').findFirst();
    expect(unread, isNull);
  });

  test('creates one reply-edge per parent, excluding the root', () async {
    final handler = Kind1NoteHandler(activePubkey: _kSelf);
    await handler.handle(
      _event(
        id: 'n1',
        tags: [
          ['e', 'root-1', '', 'root'],
          ['e', 'parent-1', '', 'reply'],
          ['e', 'mention-1', '', 'mention'],
        ],
      ),
      isar,
    );

    final edges =
        await isar.noteRelationModels.where().childIdEqualTo('n1').findAll();
    expect(edges.map((e) => e.parentId).toSet(), {'parent-1', 'mention-1'});
  });

  test('re-delivery of an existing event is idempotent (no duplicate '
      'unread row, no duplicate edges)', () async {
    final handler = Kind1NoteHandler(activePubkey: _kSelf);
    final evt = _event(id: 'n1', tags: [
      ['e', 'parent-1', '', 'reply'],
    ]);
    await handler.handle(evt, isar);
    await handler.handle(evt, isar);

    expect(await isar.noteModels.where().count(), 1);
    expect(await isar.unreadNoteModels.where().count(), 1);
    expect(
      await isar.noteRelationModels.where().childIdEqualTo('n1').count(),
      1,
    );
  });

  test('backfills rawEventJson on an existing row that lacks it (own-note '
      'optimistic-insert echo)', () async {
    // Simulate an optimistically-inserted own note with no raw JSON yet.
    await isar.writeTxn(() async {
      await isar.noteModels.put(NoteModel(
        eventId: 'n1',
        sig: 'sig',
        authorPubkey: _kAlice,
        content: 'hello',
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      ));
    });

    final handler = Kind1NoteHandler(activePubkey: _kSelf);
    await handler.handle(_event(id: 'n1'), isar);

    final row = await isar.noteModels.where().eventIdEqualTo('n1').findFirst();
    expect(row!.rawEventJson, isNotNull);
  });

  test('an unparseable embeddedNoteJson tag passes through unchanged '
      '(verifyAndSanitize cannot blank what it cannot decode)', () async {
    final handler = Kind1NoteHandler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'n1', tags: [
        [EmbeddedNoteCodec.tagName, 'not-a-valid-snapshot'],
      ]),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('n1').findFirst();
    expect(row!.embeddedNoteJson, 'not-a-valid-snapshot');
  });

  test('tags shorter than 2 elements are skipped without throwing',
      () async {
    final handler = Kind1NoteHandler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'n1', tags: const [
        ['e'],
        [],
      ]),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('n1').findFirst();
    expect(row, isNotNull);
    expect(row!.eTagRefs, isEmpty);
  });
}
