import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';

import '../../_helpers/isar_test_harness.dart';

/// Edge-table CRUD tests for [NoteRelationRepositoryImpl]. The repo is tiny
/// but its results back every reference/comment count surfaced in the UI
/// (NoteCard, Brahma graph node panel, thread page); if the math here drifts,
/// every count in the app drifts with it.
///
/// What this proves:
///   - `addEdgesInTxn` writes one row per parent in the input set.
///   - The unique compound index dedupes (parent, child) — re-adding the
///     same edge does NOT inflate counts.
///   - `replyCount` and `referenceCount` are exact inverses of each other
///     (one counts incoming, the other counts outgoing).
///   - `childIdsOf` / `parentIdsOf` return every edge endpoint, no extras.
///   - Counts stay correct after high-fan-in (many → 1) and high-fan-out
///     (1 → many) writes.
void main() {
  late Isar isar;
  late NoteRelationRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = NoteRelationRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<void> addEdge(String parent, String child) async {
    await isar.writeTxn(() async {
      await repo.addEdgesInTxn(parents: {parent}, childId: child);
    });
  }

  group('addEdgesInTxn', () {
    test('writes one row per (parent, child) pair', () async {
      await isar.writeTxn(() async {
        await repo.addEdgesInTxn(parents: {'p1', 'p2', 'p3'}, childId: 'c1');
      });
      expect(await isar.noteRelationModels.where().count(), 3);
    });

    test('re-adding the same edge is idempotent (unique compound index dedupes)', () async {
      await isar.writeTxn(() async {
        await repo.addEdgesInTxn(parents: {'p1'}, childId: 'c1');
        await repo.addEdgesInTxn(parents: {'p1'}, childId: 'c1');
      });
      expect(await isar.noteRelationModels.where().count(), 1);
    });

    test('an empty parents set is a no-op', () async {
      await isar.writeTxn(() async {
        await repo.addEdgesInTxn(parents: const {}, childId: 'orphan');
      });
      expect(await isar.noteRelationModels.where().count(), 0);
    });
  });

  group('replyCount', () {
    test('counts the rows where this id is the PARENT (i.e. people referencing it)', () async {
      await addEdge('target', 'comment-1');
      await addEdge('target', 'comment-2');
      await addEdge('other', 'comment-3'); // unrelated edge
      expect(await repo.replyCount('target'), 2);
      expect(await repo.replyCount('other'), 1);
      expect(await repo.replyCount('nobody-talks-about-me'), 0);
    });
  });

  group('referenceCount', () {
    test('counts the rows where this id is the CHILD (i.e. notes it references)', () async {
      // child-1 mentions both parents → referenceCount('child-1') == 2.
      await addEdge('parent-a', 'child-1');
      await addEdge('parent-b', 'child-1');
      await addEdge('parent-a', 'child-2');
      expect(await repo.referenceCount('child-1'), 2);
      expect(await repo.referenceCount('child-2'), 1);
      expect(await repo.referenceCount('child-3'), 0);
    });
  });

  group('childIdsOf / parentIdsOf', () {
    test('returns every direct child of a node', () async {
      await addEdge('root', 'a');
      await addEdge('root', 'b');
      await addEdge('other', 'c');
      final children = (await repo.childIdsOf('root')).toSet();
      expect(children, {'a', 'b'});
    });

    test('returns every direct parent of a node', () async {
      await addEdge('p1', 'shared');
      await addEdge('p2', 'shared');
      await addEdge('p1', 'unique');
      final parents = (await repo.parentIdsOf('shared')).toSet();
      expect(parents, {'p1', 'p2'});
    });

    test('empty list (not null) for a node with no edges', () async {
      expect(await repo.childIdsOf('ghost'), isEmpty);
      expect(await repo.parentIdsOf('ghost'), isEmpty);
    });
  });

  group('Fan-out / fan-in scenarios', () {
    test('one note referencing 10 parents → replyCount(parent) is 1 for each', () async {
      // The new note "child" references 10 existing notes simultaneously.
      await isar.writeTxn(() async {
        await repo.addEdgesInTxn(
          parents: {for (var i = 0; i < 10; i++) 'p$i'},
          childId: 'child',
        );
      });
      for (var i = 0; i < 10; i++) {
        expect(await repo.replyCount('p$i'), 1);
      }
      expect(await repo.referenceCount('child'), 10);
    });

    test('10 notes referencing one parent → replyCount(parent) is 10', () async {
      for (var i = 0; i < 10; i++) {
        await addEdge('viral', 'c$i');
      }
      expect(await repo.replyCount('viral'), 10);
      expect(await repo.referenceCount('viral'), 0,
          reason: 'viral has no outgoing refs of its own');
    });

    test('mixed inbound + outbound: counts are independent', () async {
      // X references three notes (outgoing = 3) and is referenced by two
      // (incoming = 2). The two halves of the edge table don't interact.
      await addEdge('A', 'X');
      await addEdge('B', 'X');
      await addEdge('X', 'C');
      await addEdge('X', 'D');
      await addEdge('X', 'E');
      expect(await repo.replyCount('X'), 3,
          reason: 'X has 3 incoming as parent');
      expect(await repo.referenceCount('X'), 2,
          reason: 'X has 2 incoming as child');
    });
  });
}
