import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';

/// Tests for [NoteResolverRepositoryImpl] — the resolver fronting Isar for
/// every "look up note by id" path in the app (thread view, mention chips,
/// quoted-note embed, Brahma graph panel).
///
/// Verifies:
///   - `resolveById` hits the right kind (1 / 42 / 14 / 9023) — one collection,
///     correct fields surfaced.
///   - Missing note returns `Left(notFoundFailure)` from `resolveById` but
///     `Right(null)` from `resolveNoteById` (parent/mention may be absent).
///   - Counts are stitched fresh from the edge table on every read.
///   - `resolveReplies` reads from the edge table, not from
///     `replyToEventIdEqualTo` — mentions-only references still appear.
///   - `resolveReplies` ordering is chronological by `created`.
///   - `resolveMany` skips unknown ids without erroring.
///   - The `embeddedNoteJson` snapshot becomes `quotedNote` on the resolved
///     entity (no Isar lookup, retention-immune).
void main() {
  late Isar isar;
  late NoteRelationRepositoryImpl relations;
  late NoteResolverRepositoryImpl resolver;

  setUp(() async {
    isar = await openTestIsar();
    relations = NoteRelationRepositoryImpl(isar: isar);
    resolver = NoteResolverRepositoryImpl(
      isar: isar,
      relations: relations,
      attachments: NoteAttachmentsEnricher(isar: isar),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  NoteModel feedNote(String id,
          {String content = 'body',
          DateTime? created,
          String? embeddedNoteJson}) =>
      noteRow(
        id,
        content: content,
        authorPubkey: 'pub',
        sig: 's',
        created: created ?? DateTime(2026, 1, 1),
        embeddedNoteJson: embeddedNoteJson,
      );

  NoteModel groupMessage(String id, String groupId) => noteRow(
        id,
        content: 'msg',
        authorPubkey: 'pub',
        sig: 's',
        kind: kGroupMessageKind,
        groupId: groupId,
        created: DateTime(2026, 1, 1),
      );

  NoteModel dmNote(String id, int conversationId) => noteRow(
        id,
        content: 'dm',
        authorPubkey: 'pub',
        sig: 's',
        kind: kDmTextKind,
        conversationId: conversationId,
        created: DateTime(2026, 1, 1),
      );

  // ── resolveById / resolveNoteById ────────────────────────────────────────

  group('resolveById', () {
    test('returns the feed note with stitched edge-table counts', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote('A'));
        await isar.noteRelationModels
            .put(relationEdge('A', 'B', createdAt: DateTime(2026, 1, 1)));
        await isar.noteRelationModels
            .put(relationEdge('A', 'C', createdAt: DateTime(2026, 1, 1)));
      });
      final res = await resolver.resolveById('A');
      final n = res.getOrElse(() => throw 'left');
      expect(n.id, 'A');
      expect(n.cachedReplyCount, 2);
    });

    test('returns notFoundFailure when the id is unknown', () async {
      final res = await resolver.resolveById('ghost');
      expect(res.isLeft(), isTrue);
      res.fold(
        (f) => expect(f.toString().toLowerCase(), contains('not found')),
        (_) => fail('expected Left'),
      );
    });

    test('routes a Kind-42 group message to sourceGroupId on the entity', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(groupMessage('g-1', 'group-id-1'));
      });
      final n = (await resolver.resolveById('g-1')).getOrElse(() => throw 'left');
      expect(n.sourceGroupId, 'group-id-1');
      expect(n.kind, kGroupMessageKind);
    });

    test('routes a Kind-14 DM to conversationId on the entity', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(dmNote('dm-1', 42));
      });
      final n = (await resolver.resolveById('dm-1')).getOrElse(() => throw 'left');
      expect(n.conversationId, 42);
      expect(n.kind, kDmTextKind);
    });
  });

  group('resolveNoteById', () {
    test('returns Right(null) when missing (NOT a Left) — parent/mention may be absent', () async {
      final res = await resolver.resolveNoteById('ghost');
      expect(res.isRight(), isTrue);
      expect(res.getOrElse(() => throw 'left'), isNull);
    });

    test('returns Right(NoteEntity) when present', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote('A'));
      });
      final res = await resolver.resolveNoteById('A');
      final n = res.getOrElse(() => throw 'left');
      expect(n, isNotNull);
      expect(n!.id, 'A');
    });
  });

  // ── resolveReplies ──────────────────────────────────────────────────────

  group('resolveReplies (edge-table backed)', () {
    test('returns every child of the parent — including mention-only refs', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote('parent'));
        await isar.noteModels.put(feedNote('reply'));
        await isar.noteModels.put(feedNote('mention'));
        // Both children edge into the parent — the resolver reads childIdsOf,
        // so both show up regardless of whether they used NIP-10 reply markers
        // or just an eTagRefs mention.
        await isar.noteRelationModels.put(
            relationEdge('parent', 'reply', createdAt: DateTime(2026, 1, 1)));
        await isar.noteRelationModels.put(
            relationEdge('parent', 'mention', createdAt: DateTime(2026, 1, 2)));
      });
      final replies =
          (await resolver.resolveReplies('parent')).getOrElse(() => []);
      expect(replies.map((n) => n.id).toSet(), {'reply', 'mention'});
    });

    test('sorted chronologically by created', () async {
      await isar.writeTxn(() async {
        await isar.noteModels
            .put(feedNote('parent', created: DateTime(2026, 1, 1)));
        await isar.noteModels
            .put(feedNote('late', created: DateTime(2026, 6, 1)));
        await isar.noteModels
            .put(feedNote('early', created: DateTime(2026, 2, 1)));
        await isar.noteRelationModels.put(
            relationEdge('parent', 'late', createdAt: DateTime(2026, 6, 1)));
        await isar.noteRelationModels.put(
            relationEdge('parent', 'early', createdAt: DateTime(2026, 2, 1)));
      });
      final replies =
          (await resolver.resolveReplies('parent')).getOrElse(() => []);
      expect(replies.map((n) => n.id), ['early', 'late']);
    });

    test('empty list when the parent has no edges', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote('lone'));
      });
      expect(
        (await resolver.resolveReplies('lone')).getOrElse(() => <NoteEntity>[]),
        isEmpty,
      );
    });

    test('edge with deleted child row is silently dropped (NOT an error)', () async {
      // The doc-comment is explicit: counts may exceed renderable replies if
      // a child was evicted but its edge survives. Verify the resolver tolerates this.
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote('parent'));
        // Edge points to "ghost", but no NoteModel row exists for it.
        await isar.noteRelationModels.put(
            relationEdge('parent', 'ghost', createdAt: DateTime(2026, 1, 1)));
      });
      final replies =
          (await resolver.resolveReplies('parent')).getOrElse(() => []);
      expect(replies, isEmpty,
          reason: 'evicted child silently dropped — count badge may still be 1');
      // But the count from the edge table IS 1.
      expect(await relations.replyCount('parent'), 1);
    });
  });

  // ── resolveMany ─────────────────────────────────────────────────────────

  group('resolveMany', () {
    test('returns each known id in order; drops unknown ids silently', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote('A'));
        await isar.noteModels.put(feedNote('B'));
      });
      final out = (await resolver.resolveMany(['A', 'ghost', 'B']))
          .getOrElse(() => []);
      expect(out.map((n) => n.id), ['A', 'B']);
    });

    test('all-unknown → empty list, not an error', () async {
      final out = (await resolver.resolveMany(['x', 'y']))
          .getOrElse(() => <NoteEntity>[]);
      expect(out, isEmpty);
    });
  });

  // ── embeddedNoteJson → quotedNote ───────────────────────────────────────

  group('embeddedNoteJson → quotedNote', () {
    test('snapshot decodes into a quotedNote on the resolved entity (no Isar lookup)', () async {
      // Build a valid signed-event-shaped JSON snapshot. The decoder requires
      // every field of the inner event; we provide a self-contained note.
      final inner = <String, dynamic>{
        'id': 'q' * 64,
        'pubkey': 'p' * 64,
        'created_at': DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
        'kind': 1,
        'tags': const <List<String>>[],
        'content': 'quoted body',
        'sig': '', // intentionally blank → renderer shows "unverified" badge.
      };
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote(
          'outer',
          content: 'I quote: …',
          embeddedNoteJson: jsonEncode(inner),
        ));
      });
      final n =
          (await resolver.resolveById('outer')).getOrElse(() => throw 'left');
      expect(n.quotedNote, isNotNull);
      expect(n.quotedNote!.content, 'quoted body');
      // Blank sig propagates through — the UI renders it as unverified.
      expect(n.quotedNote!.sig, '');
    });

    test('no embeddedNoteJson → quotedNote is null', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(feedNote('plain'));
      });
      final n =
          (await resolver.resolveById('plain')).getOrElse(() => throw 'left');
      expect(n.quotedNote, isNull);
    });
  });
}
