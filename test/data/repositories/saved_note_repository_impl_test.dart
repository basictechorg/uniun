import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/saved_note_repository_impl.dart';

import '../../_helpers/fake_note_relations.dart';
import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_test_harness.dart';

/// End-to-end tests for [SavedNoteRepositoryImpl]. Real Isar so the sort +
/// filter + unique-index behaviour runs unstubbed. The
/// [NoteRelationRepository] is a lightweight hand-rolled recorder — the repo
/// only calls `childIdsOf` / `parentIdsOf` here.
void main() {
  late Isar isar;
  late FakeNoteRelations relations;
  late NoteAttachmentsEnricher enricher;
  late SavedNoteRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    relations = FakeNoteRelations();
    enricher = NoteAttachmentsEnricher(isar: isar);
    repo = SavedNoteRepositoryImpl(
      isar: isar,
      relations: relations,
      attachments: enricher,
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  // ── saveNote ─────────────────────────────────────────────────────────────

  group('saveNote', () {
    test('persists a row + returns the SavedNoteEntity', () async {
      final r = await repo.saveNote(aNote(id: 'ev-1', content: 'hi'));
      expect(r.isRight(), isTrue);
      final saved = r.getOrElse(() => throw 'unreachable');
      expect(saved.eventId, 'ev-1');
      expect(saved.content, 'hi');
      expect(saved.type, NoteType.text);
      expect(saved.savedAt, isNotNull);
      // Row persisted.
      expect(await isar.savedNoteModels.count(), 1);
    });

    test('second save on same eventId is idempotent (returns existing)',
        () async {
      final n = aNote(id: 'ev-1', content: 'v1');
      final first = await repo.saveNote(n);
      final second = await repo.saveNote(aNote(id: 'ev-1', content: 'v2'));

      expect(first.isRight(), isTrue);
      expect(second.isRight(), isTrue);
      // Second call returned the ORIGINAL row (content='v1'), did not overwrite.
      expect(second.getOrElse(() => throw 'x').content, 'v1');
      expect(await isar.savedNoteModels.count(), 1);
    });

    test('unicode/emoji/RTL content persist verbatim', () async {
      final payload = '🚀 ${Content.unicode} ${Content.rtl}';
      final r = await repo.saveNote(aNote(id: 'ev-u', content: payload));
      expect(r.isRight(), isTrue);
      expect(
          (await isar.savedNoteModels
                  .where()
                  .eventIdEqualTo('ev-u')
                  .findFirst())!
              .content,
          payload);
    });

    test('attachments are embedded onto the row', () async {
      final img = aMediaBlob(sha256: 'sha-a', mime: 'image/jpeg');
      final n = aNote(id: 'ev-att', attachments: [img]);
      final r = await repo.saveNote(n);
      expect(r.isRight(), isTrue);
      final row = (await isar.savedNoteModels
          .where()
          .eventIdEqualTo('ev-att')
          .findFirst())!;
      expect(row.attachments.single.sha256, 'sha-a');
      expect(row.attachments.single.mime, 'image/jpeg');
    });

    test('root + reply threading fields round-trip', () async {
      final reply = aNote(
        id: 'ev-r',
        content: 'reply',
        rootEventId: 'root',
        replyToEventId: 'parent',
      );
      await repo.saveNote(reply);
      final row = (await isar.savedNoteModels
          .where()
          .eventIdEqualTo('ev-r')
          .findFirst())!;
      expect(row.rootEventId, 'root');
      expect(row.replyToEventId, 'parent');
    });
  });

  // ── unsaveNote ───────────────────────────────────────────────────────────

  group('unsaveNote', () {
    test('removes the row', () async {
      await repo.saveNote(aNote(id: 'ev-1'));
      final r = await repo.unsaveNote('ev-1');
      expect(r.isRight(), isTrue);
      expect(await isar.savedNoteModels.count(), 0);
    });

    test('unsave of non-existent id is a no-op Right', () async {
      final r = await repo.unsaveNote('ghost');
      expect(r.isRight(), isTrue);
    });

    test('unsave then re-save works (fresh row)', () async {
      await repo.saveNote(aNote(id: 'ev-1', content: 'first'));
      await repo.unsaveNote('ev-1');
      await repo.saveNote(aNote(id: 'ev-1', content: 'second'));
      final row = (await isar.savedNoteModels
          .where()
          .eventIdEqualTo('ev-1')
          .findFirst())!;
      expect(row.content, 'second');
    });
  });

  // ── isSaved ──────────────────────────────────────────────────────────────

  group('isSaved', () {
    test('true when row exists, false otherwise', () async {
      await repo.saveNote(aNote(id: 'ev-1'));
      expect((await repo.isSaved('ev-1')).getOrElse(() => false), isTrue);
      expect((await repo.isSaved('ghost')).getOrElse(() => true), isFalse);
    });
  });

  // ── getAll ordering ──────────────────────────────────────────────────────

  group('getAll', () {
    test('empty repo → empty list', () async {
      final r = await repo.getAll();
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw 'x'), isEmpty);
    });

    test('newest-savedAt first', () async {
      await repo.saveNote(aNote(id: 'a'));
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.saveNote(aNote(id: 'b'));
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.saveNote(aNote(id: 'c'));
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.map((e) => e.eventId).toList(), ['c', 'b', 'a']);
    });
  });

  // ── Saved-scoped counts ──────────────────────────────────────────────────

  group('saved-scoped counts', () {
    test(
        'cachedReplyCount = only edges whose child is ALSO saved '
        '(unsaved children ignored)', () async {
      await repo.saveNote(aNote(id: 'root'));
      await repo.saveNote(aNote(id: 'child-saved'));
      // Two children in the edge table, only one is saved.
      relations.children['root'] = ['child-saved', 'child-unsaved'];

      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      final root = list.firstWhere((e) => e.eventId == 'root');
      expect(root.cachedReplyCount, 1);
    });

    test(
        'referenceCount = only parent edges whose parent is ALSO saved',
        () async {
      await repo.saveNote(aNote(id: 'referrer'));
      await repo.saveNote(aNote(id: 'parent-saved'));
      relations.parents['referrer'] = ['parent-saved', 'parent-unsaved'];

      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      final ref = list.firstWhere((e) => e.eventId == 'referrer');
      expect(ref.referenceCount, 1);
    });
  });

  // ── getSavedReplies / getSavedReferences ─────────────────────────────────

  group('getSavedReplies', () {
    test('empty when parent has no edges', () async {
      final r = await repo.getSavedReplies('lonely');
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw 'x'), isEmpty);
    });

    test(
        'returns replies whose eventId is saved, sorted by created ascending',
        () async {
      final t0 = DateTime(2026, 1, 1);
      await repo.saveNote(
          aNote(id: 'r-old', created: t0.add(const Duration(minutes: 1))));
      await repo.saveNote(
          aNote(id: 'r-new', created: t0.add(const Duration(minutes: 5))));
      await repo.saveNote(aNote(id: 'r-mid', created: t0.add(const Duration(minutes: 3))));
      // relations reports 3 children; all are saved so all three should return.
      relations.children['parent'] = ['r-new', 'r-old', 'r-mid'];
      final r = await repo.getSavedReplies('parent');
      expect(
          r.getOrElse(() => throw 'x').map((e) => e.eventId).toList(),
          ['r-old', 'r-mid', 'r-new']);
    });

    test('unsaved children are dropped', () async {
      await repo.saveNote(aNote(id: 'r-1'));
      relations.children['parent'] = ['r-1', 'r-2-unsaved'];
      final r = await repo.getSavedReplies('parent');
      expect(r.getOrElse(() => throw 'x').map((e) => e.eventId).toList(),
          ['r-1']);
    });
  });

  group('getSavedReferences', () {
    test('empty when child has no parents', () async {
      final r = await repo.getSavedReferences('orphan');
      expect(r.getOrElse(() => throw 'x'), isEmpty);
    });

    test('only saved parents surface, sorted by created ascending', () async {
      final t0 = DateTime(2026, 6, 1);
      await repo.saveNote(aNote(id: 'p-a', created: t0));
      await repo.saveNote(
          aNote(id: 'p-b', created: t0.add(const Duration(hours: 1))));
      relations.parents['child'] = ['p-b', 'p-a', 'p-unsaved'];
      final r = await repo.getSavedReferences('child');
      expect(r.getOrElse(() => throw 'x').map((e) => e.eventId).toList(),
          ['p-a', 'p-b']);
    });
  });

  // ── getSavedReplyCount (thread-root scoped) ──────────────────────────────

  group('getSavedReplyCount', () {
    test('counts saved rows whose rootEventId matches', () async {
      await repo.saveNote(aNote(
        id: 'reply-1',
        rootEventId: 'thread',
        replyToEventId: 'thread',
      ));
      await repo.saveNote(aNote(
        id: 'reply-2',
        rootEventId: 'thread',
        replyToEventId: 'reply-1',
      ));
      await repo.saveNote(aNote(
        id: 'reply-other',
        rootEventId: 'other-thread',
        replyToEventId: 'other-thread',
      ));
      final r = await repo.getSavedReplyCount('thread');
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => -1), 2);
    });

    test('empty thread returns 0', () async {
      final r = await repo.getSavedReplyCount('never-seen');
      expect(r.getOrElse(() => -1), 0);
    });
  });

  // ── Scale ────────────────────────────────────────────────────────────────

  group('scale', () {
    test('100 saves round-trip', () async {
      for (var i = 0; i < 100; i++) {
        await repo.saveNote(aNote(id: 'ev-$i'));
      }
      expect(await isar.savedNoteModels.count(), 100);
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list, hasLength(100));
    });
  });
}

