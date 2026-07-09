// Integration tests for the two note mesh-sync scopes.
//
// [SignedNoteSyncScope] forwards real signed Kind 1/42 events verbatim over
// negentropy (the PublicEventSyncScope pattern). [PrivateNoteSyncScope] wraps
// the unsigned surfaces (DM 14/15, private group 9023) in a fabricated,
// self-encrypted addressable mesh event (Kind 30530). Real Isar, real keys.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/features/mesh/sync/scopes/private_note_sync_scope.dart';
import 'package:uniun/features/mesh/sync/scopes/signed_note_sync_scope.dart';

import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/mesh_test_helpers.dart';

void main() {
  stubSecureStorageChannel();

  late Isar isar;
  late MeshIdentity me;

  setUp(() async {
    isar = await openTestIsar();
    me = MeshIdentity.generate();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Event feedEvent({String content = 'hello', int createdAt = 1700000000}) =>
      Event.from(
        kind: 1,
        tags: const [],
        content: content,
        privkey: me.privkey,
        createdAt: createdAt,
      );

  NoteModel noteFromEvent(Event e) => NoteModel(
        eventId: e.id,
        sig: e.sig,
        authorPubkey: e.pubkey,
        content: e.content,
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime.fromMillisecondsSinceEpoch(e.createdAt * 1000),
        rawEventJson: jsonEncode(e.toJson()),
      );

  NoteModel dmRow(
    String id, {
    required String author,
    int conversationId = 42,
    int kind = kDmTextKind,
  }) =>
      NoteModel(
        eventId: id,
        sig: '',
        authorPubkey: author,
        content: 'a dm',
        kind: kind,
        conversationId: conversationId,
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

  group('SignedNoteSyncScope', () {
    late SignedNoteSyncScope scope;

    setUp(() {
      scope = SignedNoteSyncScope(isar, activePubkeyHex: me.pubkey);
    });

    test('localIndex advertises only kind 1/42 rows carrying rawEventJson',
        () async {
      final e = feedEvent();
      await isar.writeTxn(() => isar.noteModels.put(noteFromEvent(e)));
      // A DM row (kind 14, no rawEventJson) must NOT be advertised here.
      await isar.writeTxn(
          () => isar.noteModels.put(dmRow('dm1', author: 'bob')));

      final index = await scope.localIndex();
      expect(index.keys.toList(), [e.id]);
      expect(index[e.id], e.createdAt);
    });

    test('signedEvent returns the raw event json verbatim', () async {
      final e = feedEvent();
      await isar.writeTxn(() => isar.noteModels.put(noteFromEvent(e)));
      await scope.localIndex();
      expect(await scope.signedEvent(e.id), jsonEncode(e.toJson()));
    });

    test('upsertSigned inserts a valid note + unconditional unread row',
        () async {
      final e = feedEvent();
      await scope.upsertSigned(jsonEncode(e.toJson()));

      final note =
          await isar.noteModels.where().eventIdEqualTo(e.id).findFirst();
      expect(note, isNotNull);
      expect(note!.rawEventJson, isNotNull);
      // Unread even though it's our own note (mesh banner semantics).
      final unread =
          await isar.unreadNoteModels.where().eventIdEqualTo(e.id).findFirst();
      expect(unread, isNotNull);
    });

    test('upsertSigned drops a tampered event (invalid id/sig)', () async {
      final e = feedEvent();
      final raw = jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>;
      raw['content'] = 'tampered after signing';
      await scope.upsertSigned(jsonEncode(raw));
      expect(await isar.noteModels.count(), 0);
    });

    test('upsertSigned does not resurrect a locally-tombstoned note', () async {
      final e = feedEvent();
      await isar.writeTxn(() => isar.deletedNoteModels.put(
            DeletedNoteModel()
              ..eventId = e.id
              ..deletedAt = DateTime.now(),
          ));
      await scope.upsertSigned(jsonEncode(e.toJson()));
      expect(
        await isar.noteModels.where().eventIdEqualTo(e.id).findFirst(),
        isNull,
      );
    });
  });

  group('PrivateNoteSyncScope', () {
    PrivateNoteSyncScope scopeOn(Isar db) => PrivateNoteSyncScope(
          db,
          me.codec,
          NoteRelationRepositoryImpl(isar: db),
          activePubkeyHex: me.pubkey,
        );

    test('localIndex signs pending DM rows so a peer can rebuild them',
        () async {
      final scopeA = scopeOn(isar);
      await isar.writeTxn(() => isar.noteModels.put(dmRow('dm1', author: 'bob')));

      // localIndex fabricates the wrapper for the unsigned row and advertises it.
      final index = await scopeA.localIndex();
      expect(index.length, 1);
      final row = await isar.noteModels.where().eventIdEqualTo('dm1').findFirst();
      expect(row!.privateMeshEventJson, isNotNull);

      // The pool is keyed by the fabricated wrapper's event id, not the note id.
      final signed = await scopeA.signedEvent(index.keys.first);

      // A second same-identity device applies the wrapper.
      final isarB = await openTestIsar();
      addTearDown(() => isarB.close(deleteFromDisk: true));
      await scopeOn(isarB).upsertSigned(signed!);

      final dm =
          await isarB.noteModels.where().eventIdEqualTo('dm1').findFirst();
      expect(dm, isNotNull);
      expect(dm!.kind, kDmTextKind);
      expect(dm.conversationId, 42);
      expect(dm.authorPubkey, 'bob');
      // Foreign author → unread on the receiving device.
      final unread =
          await isarB.unreadNoteModels.where().eventIdEqualTo('dm1').findFirst();
      expect(unread, isNotNull);
    });

    test('own DM does not get an unread row on the peer', () async {
      final scopeA = scopeOn(isar);
      await isar.writeTxn(
          () => isar.noteModels.put(dmRow('dm2', author: me.pubkey)));
      final index = await scopeA.localIndex();
      final signed = await scopeA.signedEvent(index.keys.first);

      final isarB = await openTestIsar();
      addTearDown(() => isarB.close(deleteFromDisk: true));
      await scopeOn(isarB).upsertSigned(signed!);

      final dm =
          await isarB.noteModels.where().eventIdEqualTo('dm2').findFirst();
      expect(dm, isNotNull);
      final unread =
          await isarB.unreadNoteModels.where().eventIdEqualTo('dm2').findFirst();
      expect(unread, isNull);
    });

    test('private-group (9023) messages round-trip through the wrapper',
        () async {
      final scopeA = scopeOn(isar);
      await isar.writeTxn(() => isar.noteModels.put(
            NoteModel(
              eventId: 'pg1',
              sig: '',
              authorPubkey: 'carol',
              content: 'secret',
              kind: kPrivateGroupKind,
              privateGroupId: 'group-1',
              type: NoteType.text,
              eTagRefs: const [],
              pTagRefs: const [],
              tTags: const [],
              created: DateTime.fromMillisecondsSinceEpoch(1700000002000),
            ),
          ));
      final index = await scopeA.localIndex();
      final signed = await scopeA.signedEvent(index.keys.first);

      final isarB = await openTestIsar();
      addTearDown(() => isarB.close(deleteFromDisk: true));
      await scopeOn(isarB).upsertSigned(signed!);

      final pg =
          await isarB.noteModels.where().eventIdEqualTo('pg1').findFirst();
      expect(pg, isNotNull);
      expect(pg!.kind, kPrivateGroupKind);
      expect(pg.privateGroupId, 'group-1');
    });
  });
}
