import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../../_helpers/isar_test_harness.dart';

/// Broad coverage for [NoteRepositoryImpl] — getFeed pagination, saveNote
/// idempotency, getNoteById, getReplies fan-in (NIP-10 reply + root-only +
/// mention), getThread, count APIs, search, and own-notes filtering.
///
/// Each test uses a real on-disk Isar via [openTestIsar] so index-backed
/// queries, sort orders, and the edge-table writes inside [saveNote] all run
/// for real.
void main() {
  late Isar isar;
  late NoteRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    final relations = NoteRelationRepositoryImpl(isar: isar);
    repo = NoteRepositoryImpl(
      isar: isar,
      relations: relations,
      resolver: NoteResolverRepositoryImpl(
        isar: isar,
        relations: relations,
        attachments: NoteAttachmentsEnricher(isar: isar),
      ),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  NoteEntity note({
    required String id,
    String? rootEventId,
    String? replyToEventId,
    List<String> eTagRefs = const [],
    DateTime? created,
    String pubkey = 'pubkey-1',
    String content = 'hello',
  }) =>
      NoteEntity(
        id: id,
        sig: 'sig',
        authorPubkey: pubkey,
        content: content,
        type: NoteType.text,
        eTagRefs: eTagRefs,
        pTagRefs: const [],
        tTags: const [],
        created: created ?? DateTime(2026, 6, 1),
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
      );

  // ── saveNote ──────────────────────────────────────────────────────────────

  group('saveNote', () {
    test('persists a new note and returns it with counts', () async {
      final res = await repo.saveNote(note(id: 'A'));
      expect(res.isRight(), isTrue);
      final e = res.getOrElse(() => throw 'left');
      expect(e.id, 'A');
      expect(e.cachedReplyCount, 0);
      expect(e.referenceCount, 0);
    });

    test('idempotent — saving the same eventId twice keeps one row', () async {
      await repo.saveNote(note(id: 'A'));
      await repo.saveNote(note(id: 'A', content: 'overwrite attempt'));
      expect(await isar.noteModels.where().count(), 1);
      final stored = (await repo.getNoteById('A')).getOrElse(() => throw 'left');
      // First write wins; the second is dropped. Nostr immutability.
      expect(stored.content, 'hello');
    });

    test('NIP-10 reply edge populates the relation table', () async {
      await repo.saveNote(note(id: 'root'));
      await repo.saveNote(note(
        id: 'reply',
        rootEventId: 'root',
        replyToEventId: 'root',
        eTagRefs: ['root'],
      ));
      final root = (await repo.getNoteById('root')).getOrElse(() => throw 'left');
      expect(root.cachedReplyCount, 1);
    });

    test('mention-only e-tag also produces a reference edge', () async {
      await repo.saveNote(note(id: 'A'));
      await repo.saveNote(note(id: 'B', eTagRefs: ['A']));
      final a = (await repo.getNoteById('A')).getOrElse(() => throw 'left');
      final b = (await repo.getNoteById('B')).getOrElse(() => throw 'left');
      expect(a.cachedReplyCount, 1);
      expect(b.referenceCount, 1);
    });
  });

  // ── getNoteById ───────────────────────────────────────────────────────────

  group('getNoteById', () {
    test('returns the note with fresh edge-table counts', () async {
      await repo.saveNote(note(id: 'A'));
      await repo.saveNote(note(id: 'B', eTagRefs: ['A']));
      await repo.saveNote(note(id: 'C', eTagRefs: ['A']));
      final a = (await repo.getNoteById('A')).getOrElse(() => throw 'left');
      expect(a.cachedReplyCount, 2);
    });

    test('returns Left when missing', () async {
      final res = await repo.getNoteById('ghost');
      expect(res.isLeft(), isTrue);
    });
  });

  // ── getFeed ───────────────────────────────────────────────────────────────

  group('getFeed', () {
    test('returns notes newest-first', () async {
      await repo.saveNote(note(id: 'old', created: DateTime(2026, 1, 1)));
      await repo.saveNote(note(id: 'new', created: DateTime(2026, 6, 1)));
      await repo.saveNote(note(id: 'mid', created: DateTime(2026, 3, 1)));

      final feed = (await repo.getFeed(limit: 10)).getOrElse(() => []);
      expect(feed.map((n) => n.id), ['new', 'mid', 'old']);
    });

    test('respects the limit', () async {
      for (var i = 0; i < 5; i++) {
        await repo.saveNote(note(
          id: 'n$i',
          created: DateTime(2026, 1, i + 1),
        ));
      }
      final feed = (await repo.getFeed(limit: 2)).getOrElse(() => []);
      expect(feed, hasLength(2));
    });

    test('`before` cursor returns strictly older notes', () async {
      await repo.saveNote(note(id: 'a', created: DateTime(2026, 1, 1)));
      await repo.saveNote(note(id: 'b', created: DateTime(2026, 2, 1)));
      await repo.saveNote(note(id: 'c', created: DateTime(2026, 3, 1)));

      final page = (await repo.getFeed(
        limit: 10,
        before: DateTime(2026, 2, 15),
      ))
          .getOrElse(() => []);
      expect(page.map((n) => n.id), ['b', 'a']);
    });

    test('empty feed → empty list, no error', () async {
      final feed = (await repo.getFeed(limit: 10)).getOrElse(() => <NoteEntity>[]);
      expect(feed, isNotNull);
      expect(feed, isEmpty);
    });

    test('feed includes replies, not just top-level posts', () async {
      // Per the impl comment: feed shows every note. Brahma graph and Vishnu
      // are responsible for filtering, not the data layer.
      await repo.saveNote(note(id: 'root'));
      await repo.saveNote(note(
        id: 'reply',
        rootEventId: 'root',
        replyToEventId: 'root',
        eTagRefs: ['root'],
      ));
      final feed = (await repo.getFeed(limit: 10)).getOrElse(() => []);
      expect(feed.map((n) => n.id).toSet(), {'root', 'reply'});
    });
  });

  // ── getReplies — fan-in across reply / root-only / mention edges ─────────

  group('getReplies', () {
    test('returns NIP-10 direct replies', () async {
      await repo.saveNote(note(id: 'root'));
      await repo.saveNote(note(
        id: 'r1',
        rootEventId: 'root',
        replyToEventId: 'root',
        eTagRefs: ['root'],
      ));
      await repo.saveNote(note(
        id: 'r2',
        rootEventId: 'root',
        replyToEventId: 'root',
        eTagRefs: ['root'],
      ));
      final replies = (await repo.getReplies('root')).getOrElse(() => []);
      expect(replies.map((n) => n.id).toSet(), {'r1', 'r2'});
    });

    test('returns root-only e-tag children (no reply marker)', () async {
      await repo.saveNote(note(id: 'root'));
      await repo.saveNote(note(
        id: 'r1',
        rootEventId: 'root',
        eTagRefs: ['root'],
      ));
      final replies = (await repo.getReplies('root')).getOrElse(() => []);
      expect(replies.map((n) => n.id), ['r1']);
    });

    test('returns mention-only references (not in NIP-10 reply graph)', () async {
      await repo.saveNote(note(id: 'A'));
      await repo.saveNote(note(id: 'B', eTagRefs: ['A']));
      final refs = (await repo.getReplies('A')).getOrElse(() => []);
      expect(refs.map((n) => n.id), ['B']);
    });

    test('deduplicates a note that hits multiple criteria', () async {
      await repo.saveNote(note(id: 'A'));
      // This note simultaneously NIP-10-replies AND appears in eTagRefs.
      await repo.saveNote(note(
        id: 'B',
        rootEventId: 'A',
        replyToEventId: 'A',
        eTagRefs: ['A'],
      ));
      final replies = (await repo.getReplies('A')).getOrElse(() => []);
      expect(replies.map((n) => n.id), ['B']);
    });

    test('chronological order regardless of which path matched', () async {
      await repo.saveNote(note(id: 'root'));
      await repo.saveNote(note(
        id: 'mention-late',
        eTagRefs: ['root'],
        created: DateTime(2026, 6, 1),
      ));
      await repo.saveNote(note(
        id: 'reply-early',
        rootEventId: 'root',
        replyToEventId: 'root',
        eTagRefs: ['root'],
        created: DateTime(2026, 1, 1),
      ));
      final replies = (await repo.getReplies('root')).getOrElse(() => []);
      expect(replies.map((n) => n.id), ['reply-early', 'mention-late']);
    });

    test('does NOT include the root itself in its own reply list', () async {
      await repo.saveNote(note(id: 'A'));
      // Pathological self-reference: a note's eTagRefs contains its own id.
      await repo.saveNote(note(id: 'self-ref', eTagRefs: ['self-ref']));
      final replies = (await repo.getReplies('self-ref')).getOrElse(() => []);
      expect(replies.where((n) => n.id == 'self-ref'), isEmpty);
    });
  });

  // ── getThread ─────────────────────────────────────────────────────────────

  group('getThread', () {
    test('returns root + every descendant by rootEventId, chronological', () async {
      await repo.saveNote(note(id: 'root', created: DateTime(2026, 1, 1)));
      await repo.saveNote(note(
        id: 'r1',
        rootEventId: 'root',
        replyToEventId: 'root',
        eTagRefs: ['root'],
        created: DateTime(2026, 1, 2),
      ));
      await repo.saveNote(note(
        id: 'r2',
        rootEventId: 'root',
        replyToEventId: 'r1',
        eTagRefs: ['root', 'r1'],
        created: DateTime(2026, 1, 3),
      ));
      final thread = (await repo.getThread('root')).getOrElse(() => []);
      expect(thread.map((n) => n.id), ['root', 'r1', 'r2']);
    });

    test('returns just the root when no replies exist', () async {
      await repo.saveNote(note(id: 'lone'));
      final thread = (await repo.getThread('lone')).getOrElse(() => []);
      expect(thread.map((n) => n.id), ['lone']);
    });

    test('empty Right when the root is unknown', () async {
      final thread = (await repo.getThread('ghost')).getOrElse(() => <NoteEntity>[]);
      expect(thread, isNotNull);
      expect(thread, isEmpty);
    });
  });

  // ── count APIs ────────────────────────────────────────────────────────────

  group('counts', () {
    test('getReplyCount counts inbound edges (all reference types)', () async {
      await repo.saveNote(note(id: 'A'));
      await repo.saveNote(note(id: 'B', eTagRefs: ['A']));
      await repo.saveNote(note(
        id: 'C',
        rootEventId: 'A',
        replyToEventId: 'A',
        eTagRefs: ['A'],
      ));
      final c = (await repo.getReplyCount('A')).getOrElse(() => -1);
      expect(c, 2);
    });

    test('getThreadReplyCount counts every note bound by rootEventId', () async {
      await repo.saveNote(note(id: 'root'));
      await repo.saveNote(note(
        id: 'r1',
        rootEventId: 'root',
        replyToEventId: 'root',
        eTagRefs: ['root'],
      ));
      await repo.saveNote(note(
        id: 'r2',
        rootEventId: 'root',
        replyToEventId: 'r1',
        eTagRefs: ['root', 'r1'],
      ));
      final c = (await repo.getThreadReplyCount('root')).getOrElse(() => -1);
      expect(c, 2, reason: 'r1 + r2 carry rootEventId=root; root itself does not');
    });
  });

  // ── searchNotes ───────────────────────────────────────────────────────────

  group('searchNotes', () {
    test('finds notes by case-insensitive content substring', () async {
      await repo.saveNote(note(id: 'A', content: 'Hello WORLD'));
      await repo.saveNote(note(id: 'B', content: 'goodbye'));
      final hits = (await repo.searchNotes('world')).getOrElse(() => []);
      expect(hits.map((n) => n.id), ['A']);
    });

    test('empty / whitespace query → empty result', () async {
      await repo.saveNote(note(id: 'A', content: 'anything'));
      expect((await repo.searchNotes('')).getOrElse(() => <NoteEntity>[]), isEmpty);
      expect((await repo.searchNotes('   ')).getOrElse(() => <NoteEntity>[]), isEmpty);
    });

    test('returns newest-first', () async {
      await repo.saveNote(note(id: 'old', content: 'pizza', created: DateTime(2026, 1, 1)));
      await repo.saveNote(note(id: 'new', content: 'pizza', created: DateTime(2026, 6, 1)));
      final hits = (await repo.searchNotes('pizza')).getOrElse(() => []);
      expect(hits.map((n) => n.id), ['new', 'old']);
    });
  });

  // ── getOwnNotes ───────────────────────────────────────────────────────────

  group('getOwnNotes', () {
    test('returns only notes authored by the given pubkey, newest-first', () async {
      await repo.saveNote(note(id: 'mine-1', pubkey: 'me', created: DateTime(2026, 1, 1)));
      await repo.saveNote(note(id: 'mine-2', pubkey: 'me', created: DateTime(2026, 6, 1)));
      await repo.saveNote(note(id: 'theirs', pubkey: 'other'));

      final mine = (await repo.getOwnNotes('me')).getOrElse(() => []);
      expect(mine.map((n) => n.id), ['mine-2', 'mine-1']);
    });

    test('empty list when the pubkey has no notes', () async {
      final mine = (await repo.getOwnNotes('me')).getOrElse(() => <NoteEntity>[]);
      expect(mine, isNotNull);
      expect(mine, isEmpty);
    });
  });
}
