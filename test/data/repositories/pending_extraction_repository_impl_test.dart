import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/pending_extraction_model.dart';
import 'package:uniun/data/repositories/pending_extraction_repository_impl.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: PendingExtractionRepositoryImpl mark (unique-replace on noteId,
/// vector round-trip), clear idempotency, all() createdAt ordering.
void main() {
  late Isar isar;
  late PendingExtractionRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = PendingExtractionRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('mark', () {
    test('persists noteId + content + embedding vector', () async {
      await repo.mark('n-1', 'note text', [0.1, -0.5, 3.25]);
      final items = await repo.all();
      expect(items, hasLength(1));
      expect(items.single.noteId, 'n-1');
      expect(items.single.content, 'note text');
      expect(items.single.vec, [0.1, -0.5, 3.25]);
    });

    test('re-mark of the same noteId replaces the row (unique index)',
        () async {
      await repo.mark('n-1', 'v1', [1.0]);
      await repo.mark('n-1', 'v2', [2.0]);
      final items = await repo.all();
      expect(items, hasLength(1));
      expect(items.single.content, 'v2');
      expect(items.single.vec, [2.0]);
    });

    test('empty vector round-trips (embedder unavailable path)', () async {
      await repo.mark('n-1', 'text', const []);
      expect((await repo.all()).single.vec, isEmpty);
    });

    test('large vector (768 dims) round-trips losslessly', () async {
      final vec = [for (var i = 0; i < 768; i++) i / 768];
      await repo.mark('n-1', 'text', vec);
      expect((await repo.all()).single.vec, vec);
    });

    test('unicode content round-trips', () async {
      await repo.mark('n-1', '${Content.unicode} ${Content.emoji}', [1.0]);
      expect((await repo.all()).single.content,
          '${Content.unicode} ${Content.emoji}');
    });
  });

  group('clear', () {
    test('removes only the requested noteId', () async {
      await repo.mark('n-1', 'a', [1.0]);
      await repo.mark('n-2', 'b', [2.0]);
      await repo.clear('n-1');
      final items = await repo.all();
      expect(items.map((i) => i.noteId), ['n-2']);
    });

    test('idempotent on unknown noteId', () async {
      await repo.mark('n-1', 'a', [1.0]);
      await repo.clear('ghost');
      expect(await repo.all(), hasLength(1));
    });
  });

  group('all', () {
    test('empty database → empty list', () async {
      expect(await repo.all(), isEmpty);
    });

    test('returns items oldest-first by createdAt (queue drain order)',
        () async {
      // mark() stamps DateTime.now() — seed directly to control the clock.
      await isar.writeTxn(() async {
        for (final (i, ts) in [
          (0, tNow),
          (1, tT0),
          (2, tNow.subtract(const Duration(days: 1))),
        ]) {
          await isar.pendingExtractionModels.put(PendingExtractionModel()
            ..noteId = 'n-$i'
            ..content = 'c'
            ..vec = const []
            ..createdAt = ts);
        }
      });
      final items = await repo.all();
      expect(items.map((i) => i.noteId), ['n-1', 'n-2', 'n-0']);
    });

    test('scale: 200 pending rows drain in insertion order', () async {
      for (var i = 0; i < 200; i++) {
        await repo.mark('n-$i', 'c$i', [i.toDouble()]);
      }
      final items = await repo.all();
      expect(items, hasLength(200));
      expect(items.first.noteId, 'n-0');
      expect(items.last.noteId, 'n-199');
    });
  });
}
