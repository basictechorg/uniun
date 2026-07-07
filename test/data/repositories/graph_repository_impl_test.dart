import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/graph_edge_model.dart';
import 'package:uniun/data/models/graph_node_model.dart';
import 'package:uniun/data/repositories/graph_repository_impl.dart';
import 'package:uniun/domain/entities/graph_edge/graph_edge_entity.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: GraphRepositoryImpl upsertNode (insert/update by key), upsertEdge
/// 4-field dedup, getNeighbours (both directions, limit, empty input),
/// getEdgesForNote, getNodesByKeys, deleteForNote scoping.
void main() {
  late Isar isar;
  late GraphRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = GraphRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  List<GraphEdgeEntity> edgesOf(dynamic either) =>
      either.getOrElse(() => const <GraphEdgeEntity>[])
          as List<GraphEdgeEntity>;

  group('upsertNode', () {
    test('inserts a new node with every field mapped', () async {
      final r = await repo.upsertNode(
          aGraphNode(key: 'k-1', name: 'Rust', type: 'topic'));
      expect(r.isRight(), isTrue);

      final row = (await isar.graphNodeModels.where().findAll()).single;
      expect(row.key, 'k-1');
      expect(row.name, 'Rust');
      expect(row.type, 'topic');
    });

    test('updates name/type/updatedAt in place — createdAt survives',
        () async {
      await repo.upsertNode(aGraphNode(key: 'k-1', createdAt: tT0));
      final firstId =
          (await isar.graphNodeModels.where().findAll()).single.id;

      await repo.upsertNode(aGraphNode(
        key: 'k-1',
        name: 'Renamed',
        type: 'concept',
        createdAt: tNow, // must be ignored on update
      ));

      final rows = await isar.graphNodeModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.id, firstId);
      expect(rows.single.name, 'Renamed');
      expect(rows.single.type, 'concept');
      expect(rows.single.createdAt.isAtSameMomentAs(tT0), isTrue);
    });

    test('unicode node names round-trip', () async {
      await repo.upsertNode(aGraphNode(key: 'k-u', name: '🐉 设计 مرحبا'));
      final r = await repo.getNodesByKeys(['k-u']);
      expect(r.getOrElse(() => const []).single.name, '🐉 设计 مرحبا');
    });
  });

  group('upsertEdge', () {
    test('inserts a new edge', () async {
      final r = await repo.upsertEdge(aGraphEdge());
      expect(r.isRight(), isTrue);
      expect(await isar.graphEdgeModels.count(), 1);
    });

    test('exact duplicate (source, target, relation, sourceNote) is dropped',
        () async {
      await repo.upsertEdge(aGraphEdge());
      await repo.upsertEdge(aGraphEdge());
      expect(await isar.graphEdgeModels.count(), 1);
    });

    test('changing ANY of the four identity fields creates a new edge',
        () async {
      await repo.upsertEdge(aGraphEdge());
      await repo.upsertEdge(aGraphEdge(sourceKey: 'other'));
      await repo.upsertEdge(aGraphEdge(targetKey: 'other'));
      await repo.upsertEdge(aGraphEdge(relationType: 'links'));
      await repo.upsertEdge(aGraphEdge(sourceNoteId: 'note-2'));
      expect(await isar.graphEdgeModels.count(), 5);
    });
  });

  group('getNeighbours', () {
    test('empty keys → Right(empty)', () async {
      final r = await repo.getNeighbours(const []);
      expect(r.isRight(), isTrue);
      expect(edgesOf(r), isEmpty);
    });

    test('returns outgoing AND incoming edges of a key', () async {
      await repo.upsertEdge(
          aGraphEdge(sourceKey: 'center', targetKey: 'out-1'));
      await repo.upsertEdge(aGraphEdge(
          sourceKey: 'in-1', targetKey: 'center', sourceNoteId: 'note-2'));
      await repo.upsertEdge(aGraphEdge(
          sourceKey: 'unrelated', targetKey: 'elsewhere',
          sourceNoteId: 'note-3'));

      final r = await repo.getNeighbours(['center']);
      final edges = edgesOf(r);
      expect(edges, hasLength(2));
      expect(
        edges.map((e) => '${e.sourceKey}->${e.targetKey}').toSet(),
        {'center->out-1', 'in-1->center'},
      );
    });

    test('limit caps the result across multiple seed keys', () async {
      for (var i = 0; i < 10; i++) {
        await repo.upsertEdge(aGraphEdge(
            sourceKey: 'hub', targetKey: 't-$i', sourceNoteId: 'n-$i'));
      }
      final r = await repo.getNeighbours(['hub'], limit: 4);
      expect(edgesOf(r), hasLength(4));
    });

    test('multiple seed keys accumulate until the limit', () async {
      await repo.upsertEdge(
          aGraphEdge(sourceKey: 'a', targetKey: 'x', sourceNoteId: 'n-1'));
      await repo.upsertEdge(
          aGraphEdge(sourceKey: 'b', targetKey: 'y', sourceNoteId: 'n-2'));

      final r = await repo.getNeighbours(['a', 'b']);
      expect(edgesOf(r), hasLength(2));
    });

    test('key with no edges → Right(empty)', () async {
      final r = await repo.getNeighbours(['lonely']);
      expect(edgesOf(r), isEmpty);
    });

    test('an edge matched from both endpoints appears TWICE (identity-set '
        'quirk)', () async {
      // Current behaviour: the impl dedups via Set<GraphEdgeModel>, but Isar
      // materializes a fresh object per query and the model has no ==/hashCode
      // override — so the same row fetched as outgoing-of-a and incoming-of-b
      // is NOT collapsed. Duplicate edges can eat into the limit.
      await repo.upsertEdge(aGraphEdge(sourceKey: 'a', targetKey: 'b'));
      final r = await repo.getNeighbours(['a', 'b']);
      expect(edgesOf(r), hasLength(2));
    });
  });

  group('getEdgesForNote', () {
    test('returns only edges asserted by the note', () async {
      await repo.upsertEdge(aGraphEdge(sourceNoteId: 'note-1'));
      await repo.upsertEdge(aGraphEdge(
          sourceKey: 'other', sourceNoteId: 'note-2'));

      final r = await repo.getEdgesForNote('note-1');
      final edges = edgesOf(r);
      expect(edges, hasLength(1));
      expect(edges.single.sourceNoteId, 'note-1');
    });

    test('unknown note → Right(empty)', () async {
      expect(edgesOf(await repo.getEdgesForNote('ghost')), isEmpty);
    });
  });

  group('getNodesByKeys', () {
    test('empty input short-circuits to Right(empty)', () async {
      final r = await repo.getNodesByKeys(const []);
      expect(r.getOrElse(() => throw 'unreachable'), isEmpty);
    });

    test('returns the matching subset only', () async {
      await repo.upsertNode(aGraphNode(key: 'k-1'));
      await repo.upsertNode(aGraphNode(key: 'k-2'));
      final r = await repo.getNodesByKeys(['k-1', 'missing']);
      final keys =
          r.getOrElse(() => const []).map((n) => n.key).toList();
      expect(keys, ['k-1']);
    });
  });

  group('deleteForNote', () {
    test('removes only that note\'s edges — nodes and other edges survive',
        () async {
      await repo.upsertNode(aGraphNode(key: 'k-1'));
      await repo.upsertEdge(aGraphEdge(sourceNoteId: 'note-1'));
      await repo.upsertEdge(aGraphEdge(
          sourceKey: 'other', sourceNoteId: 'note-2'));

      final r = await repo.deleteForNote('note-1');
      expect(r.isRight(), isTrue);
      expect(await isar.graphEdgeModels.count(), 1);
      expect(await isar.graphNodeModels.count(), 1);
      expect(edgesOf(await repo.getEdgesForNote('note-2')), hasLength(1));
    });

    test('idempotent on unknown note', () async {
      expect((await repo.deleteForNote('ghost')).isRight(), isTrue);
    });
  });

  group('integration: note extraction lifecycle', () {
    test('extract → re-extract (dedup) → note delete leaves a clean graph',
        () async {
      // Extraction writes 2 nodes + 2 edges for note-1.
      await repo.upsertNode(aGraphNode(key: 'topic:rust', name: 'Rust'));
      await repo.upsertNode(aGraphNode(key: 'topic:wasm', name: 'WASM'));
      await repo.upsertEdge(aGraphEdge(
          sourceKey: 'topic:rust',
          targetKey: 'topic:wasm',
          sourceNoteId: 'note-1'));
      await repo.upsertEdge(aGraphEdge(
          sourceKey: 'topic:wasm',
          targetKey: 'topic:rust',
          sourceNoteId: 'note-1'));

      // Re-extraction of the same note is a no-op for identical assertions.
      await repo.upsertEdge(aGraphEdge(
          sourceKey: 'topic:rust',
          targetKey: 'topic:wasm',
          sourceNoteId: 'note-1'));
      expect(await isar.graphEdgeModels.count(), 2);

      // Neighbour expansion sees the cluster.
      expect(edgesOf(await repo.getNeighbours(['topic:rust'])),
          hasLength(2));

      // Removing the note's assertions clears its edges but keeps nodes
      // (they may be shared with other notes).
      await repo.deleteForNote('note-1');
      expect(await isar.graphEdgeModels.count(), 0);
      expect(await isar.graphNodeModels.count(), 2);
    });
  });
}
