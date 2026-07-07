import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/memory_node_model.dart';
import 'package:uniun/data/repositories/memory_repository_impl.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: MemoryRepositoryImpl upsert (insert + update-in-place),
/// getByNoteId, getByNoteIds batching, deleteByNoteId idempotency.
void main() {
  late Isar isar;
  late MemoryRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = MemoryRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('upsert', () {
    test('inserts a new memory node with every field mapped', () async {
      final r = await repo.upsert(aMemoryNode(
        noteId: 'n-1',
        summary: 'sum',
        keyPoints: ['k1', 'k2'],
        concepts: ['c1'],
        linkedNoteIds: ['n-2'],
      ));
      expect(r.isRight(), isTrue);

      final row = (await isar.memoryNodeModels.where().findAll()).single;
      expect(row.noteId, 'n-1');
      expect(row.summary, 'sum');
      expect(row.keyPoints, ['k1', 'k2']);
      expect(row.concepts, ['c1']);
      expect(row.linkedNoteIds, ['n-2']);
    });

    test('updates the existing row in place — same Isar id, new content',
        () async {
      await repo.upsert(aMemoryNode(noteId: 'n-1', summary: 'v1'));
      final firstId =
          (await isar.memoryNodeModels.where().findAll()).single.id;

      await repo.upsert(aMemoryNode(
          noteId: 'n-1', summary: 'v2', concepts: ['fresh']));

      final rows = await isar.memoryNodeModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.id, firstId);
      expect(rows.single.summary, 'v2');
      expect(rows.single.concepts, ['fresh']);
    });

    test('unicode summary round-trips', () async {
      await repo.upsert(aMemoryNode(
          noteId: 'n-u', summary: '${Content.unicode} ${Content.emoji}'));
      final r = await repo.getByNoteId('n-u');
      expect(r.getOrElse(() => null)?.summary,
          '${Content.unicode} ${Content.emoji}');
    });
  });

  group('getByNoteId', () {
    test('unknown noteId → Right(null)', () async {
      final r = await repo.getByNoteId('ghost');
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => aMemoryNode()), isNull);
    });

    test('round-trips the domain entity', () async {
      await repo.upsert(aMemoryNode(noteId: 'n-1', keyPoints: ['a']));
      final r = await repo.getByNoteId('n-1');
      final e = r.getOrElse(() => null)!;
      expect(e.noteId, 'n-1');
      expect(e.keyPoints, ['a']);
    });
  });

  group('getByNoteIds', () {
    test('empty input short-circuits to Right(empty)', () async {
      final r = await repo.getByNoteIds(const []);
      expect(r.getOrElse(() => throw 'unreachable'), isEmpty);
    });

    test('returns only the matching subset', () async {
      await repo.upsert(aMemoryNode(noteId: 'n-1'));
      await repo.upsert(aMemoryNode(noteId: 'n-2'));
      await repo.upsert(aMemoryNode(noteId: 'n-3'));

      final r = await repo.getByNoteIds(['n-1', 'n-3', 'missing']);
      final ids = r
          .getOrElse(() => throw 'unreachable')
          .map((e) => e.noteId)
          .toSet();
      expect(ids, {'n-1', 'n-3'});
    });

    test('100 ids resolve in one call', () async {
      for (var i = 0; i < 100; i++) {
        await repo.upsert(aMemoryNode(noteId: 'n-$i'));
      }
      final r =
          await repo.getByNoteIds([for (var i = 0; i < 100; i++) 'n-$i']);
      expect(r.getOrElse(() => throw 'unreachable'), hasLength(100));
    });
  });

  group('deleteByNoteId', () {
    test('removes the row', () async {
      await repo.upsert(aMemoryNode(noteId: 'n-1'));
      final r = await repo.deleteByNoteId('n-1');
      expect(r.isRight(), isTrue);
      expect(await isar.memoryNodeModels.count(), 0);
    });

    test('idempotent on unknown noteId', () async {
      expect((await repo.deleteByNoteId('ghost')).isRight(), isTrue);
    });
  });
}
