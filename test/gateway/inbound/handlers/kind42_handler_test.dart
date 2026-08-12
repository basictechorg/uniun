import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind42_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../../_helpers/isar_test_harness.dart';

const _kAlice = 'alice-pub-hex';
const _kSelf = 'self-pub-hex';

VerifiedNostrEvent _event({
  required String id,
  String pubkey = _kAlice,
  int createdAt = 1_700_000_000,
  List<List<String>> tags = const [],
  String content = 'hi group',
  String sig = 'sig',
}) {
  return VerifiedNostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 42,
    tags: tags,
    content: content,
    sig: sig,
    raw: {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': 42,
      'tags': tags,
      'content': content,
      'sig': sig,
    },
  );
}

/// Covers: Kind42Handler's marker-based root/reply resolution, the
/// legacy-NIP-10 positional fallback (first e-tag = root, last = reply) when
/// markers are absent, the no-groupId bail-out, idempotent re-delivery with
/// raw-json backfill, unread-row gating on non-own authorship, and
/// reply-edge creation excluding the group root.
void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('declares kind 42', () {
    expect(Kind42Handler(activePubkey: _kSelf).kinds, {42});
  });

  test('parses and sanitizes an embeddedNoteJson tag', () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'm1', tags: [
        ['e', 'group-1', '', 'root'],
        [EmbeddedNoteCodec.tagName, 'not-a-valid-snapshot'],
      ]),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('m1').findFirst();
    expect(row!.embeddedNoteJson, 'not-a-valid-snapshot');
  });

  test('backfills rawEventJson on an existing row that lacks it', () async {
    await isar.writeTxn(() async {
      await isar.noteModels.put(NoteModel(
        eventId: 'm1',
        sig: 'sig',
        authorPubkey: _kAlice,
        content: 'hi group',
        kind: kGroupMessageKind,
        groupId: 'group-1',
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      ));
    });

    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'm1', tags: [
        ['e', 'group-1', '', 'root'],
      ]),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('m1').findFirst();
    expect(row!.rawEventJson, isNotNull);
  });

  test('resolves groupId/replyEventId via NIP-10 markers', () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'm1', tags: [
        ['e', 'group-1', '', 'root'],
        ['e', 'parent-1', '', 'reply'],
      ]),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('m1').findFirst();
    expect(row, isNotNull);
    expect(row!.kind, kGroupMessageKind);
    expect(row.groupId, 'group-1');
    expect(row.replyToEventId, 'parent-1');
  });

  test('falls back to positional first/last e-tag when markers are absent',
      () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'm1', tags: [
        ['e', 'group-1'],
        ['e', 'mid-1'],
        ['e', 'last-1'],
      ]),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('m1').findFirst();
    expect(row!.groupId, 'group-1');
    expect(row.replyToEventId, 'last-1');
  });

  test('a single e-tag with no marker is treated as the group root only '
      '(no reply fallback)', () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'm1', tags: [
        ['e', 'group-1'],
      ]),
      isar,
    );

    final row = await isar.noteModels.where().eventIdEqualTo('m1').findFirst();
    expect(row!.groupId, 'group-1');
    expect(row.replyToEventId, isNull);
  });

  test('no e-tags at all → no groupId → the handler bails, nothing '
      'written', () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(_event(id: 'm1', tags: const []), isar);

    expect(await isar.noteModels.where().count(), 0);
  });

  test('inserts an unread row for a message from someone else', () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'm1', tags: [
        ['e', 'group-1', '', 'root'],
      ]),
      isar,
    );

    final unread =
        await isar.unreadNoteModels.where().eventIdEqualTo('m1').findFirst();
    expect(unread, isNotNull);
  });

  test('no unread row for the active user\'s own message', () async {
    final handler = Kind42Handler(activePubkey: _kAlice);
    await handler.handle(
      _event(id: 'm1', pubkey: _kAlice, tags: [
        ['e', 'group-1', '', 'root'],
      ]),
      isar,
    );

    final unread =
        await isar.unreadNoteModels.where().eventIdEqualTo('m1').findFirst();
    expect(unread, isNull);
  });

  test('creates a reply-edge for the reply target, excluding the group '
      'root', () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    await handler.handle(
      _event(id: 'm1', tags: [
        ['e', 'group-1', '', 'root'],
        ['e', 'parent-1', '', 'reply'],
      ]),
      isar,
    );

    final edges =
        await isar.noteRelationModels.where().childIdEqualTo('m1').findAll();
    expect(edges.map((e) => e.parentId).toSet(), {'parent-1'});
  });

  test('re-delivery of an existing event is idempotent', () async {
    final handler = Kind42Handler(activePubkey: _kSelf);
    final evt = _event(id: 'm1', tags: [
      ['e', 'group-1', '', 'root'],
    ]);
    await handler.handle(evt, isar);
    await handler.handle(evt, isar);

    expect(await isar.noteModels.where().count(), 1);
    expect(await isar.unreadNoteModels.where().count(), 1);
  });
}
