import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';

/// Direct unit tests for the dependency-first topological sort that powers
/// the publish-chain flow.
///
/// The algorithm itself is a private method on [BrahmaCreateBloc]
/// (`_topoSort`, Kahn's algorithm over the draft → draftRefIds graph). Since
/// it is pure, deterministic, and the highest-risk piece of the chain
/// publish path, this file ports it verbatim and tests every interesting
/// graph shape:
///
///   - empty / single / linear / diamond / fan-out / disconnected
///   - self-loop and 2-cycle and 3-cycle (must return null)
///   - dangling refs (target outside the closure)
///
/// The port is line-for-line identical to the BLoC's implementation; if the
/// production source ever changes, copy the new body into [_topoSort] below
/// and the existing assertions still apply. (This is the same pattern used
/// in `integration/draft_publish_flow_test.dart` for the chain BFS — these
/// tests catch *algorithm* regressions, the integration tests catch
/// *wiring* regressions.)
void main() {
  DraftEntity d(String id, [List<String> refs = const []]) => DraftEntity(
        draftId: id,
        content: id,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        draftRefIds: refs,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Map<String, DraftEntity> graph(List<DraftEntity> drafts) => {
        for (final x in drafts) x.draftId: x,
      };

  test('empty graph → empty order', () {
    expect(_topoSort(graph(const [])), <String>[]);
  });

  test('single node, no refs → [node]', () {
    expect(_topoSort(graph([d('A')])), ['A']);
  });

  test('two unrelated nodes → both in some order (order between unrelated nodes is unspecified)', () {
    final out = _topoSort(graph([d('A'), d('B')]))!;
    expect(out.toSet(), {'A', 'B'});
  });

  test('linear A → B: leaf first', () {
    expect(_topoSort(graph([d('A', ['B']), d('B')])), ['B', 'A']);
  });

  test('deep linear A → B → C → D: leaves first', () {
    final out = _topoSort(graph([
      d('A', ['B']),
      d('B', ['C']),
      d('C', ['D']),
      d('D'),
    ]))!;
    // The exact algorithm is Kahn's; assert the *dependency invariant*:
    // every node appears before any node that depends on it.
    expect(out, hasLength(4));
    expect(out.indexOf('D'), lessThan(out.indexOf('C')));
    expect(out.indexOf('C'), lessThan(out.indexOf('B')));
    expect(out.indexOf('B'), lessThan(out.indexOf('A')));
  });

  test('diamond A → {B,C} → D: D first, then B/C in either order, then A', () {
    final out = _topoSort(graph([
      d('A', ['B', 'C']),
      d('B', ['D']),
      d('C', ['D']),
      d('D'),
    ]))!;
    expect(out, hasLength(4));
    expect(out.indexOf('D'), lessThan(out.indexOf('B')));
    expect(out.indexOf('D'), lessThan(out.indexOf('C')));
    expect(out.indexOf('B'), lessThan(out.indexOf('A')));
    expect(out.indexOf('C'), lessThan(out.indexOf('A')));
  });

  test('fan-out: A → {B, C, D, E}; all leaves before A', () {
    final out = _topoSort(graph([
      d('A', ['B', 'C', 'D', 'E']),
      d('B'),
      d('C'),
      d('D'),
      d('E'),
    ]))!;
    expect(out.indexOf('A'), 4, reason: 'A is the last node');
  });

  test('two disconnected chains: A→B and X→Y', () {
    final out = _topoSort(graph([
      d('A', ['B']),
      d('B'),
      d('X', ['Y']),
      d('Y'),
    ]))!;
    expect(out, hasLength(4));
    expect(out.indexOf('B'), lessThan(out.indexOf('A')));
    expect(out.indexOf('Y'), lessThan(out.indexOf('X')));
  });

  test('cycle A → B → A → null', () {
    expect(_topoSort(graph([d('A', ['B']), d('B', ['A'])])), isNull);
  });

  test('cycle A → B → C → A → null', () {
    expect(
      _topoSort(graph([
        d('A', ['B']),
        d('B', ['C']),
        d('C', ['A']),
      ])),
      isNull,
    );
  });

  test('self-loop A → A → null', () {
    expect(_topoSort(graph([d('A', ['A'])])), isNull);
  });

  test('partial cycle (subgraph): A → {B, C}; B → C → B; → null', () {
    // The 2-cycle B↔C corrupts the whole closure; A can\'t resolve.
    expect(
      _topoSort(graph([
        d('A', ['B', 'C']),
        d('B', ['C']),
        d('C', ['B']),
      ])),
      isNull,
    );
  });

  test('dangling ref to a node NOT in the graph is ignored (skipped, no cycle)', () {
    // The chain BFS already filters dangling refs out of the closure before
    // calling topo. The algorithm itself must also tolerate them — `indegree`
    // only counts refs to nodes inside the map.
    final out = _topoSort(graph([
      d('A', ['ghost', 'B']),
      d('B'),
    ]))!;
    expect(out, hasLength(2));
    expect(out.indexOf('B'), lessThan(out.indexOf('A')));
  });

  test('every node referenced multiple times still appears exactly once', () {
    // C is referenced by both A and B. Topo must emit C once.
    final out = _topoSort(graph([
      d('A', ['B', 'C']),
      d('B', ['C']),
      d('C'),
    ]))!;
    expect(out, hasLength(3));
    expect(out.toSet(), {'A', 'B', 'C'});
  });

  test('large random-ish DAG: dependency invariant holds for every edge', () {
    // 6 nodes, multiple paths — exercise Kahn\'s ready-queue maintenance.
    final drafts = [
      d('root', ['l', 'r']),
      d('l', ['ll', 'lr']),
      d('r', ['lr', 'rr']),
      d('ll'),
      d('lr'),
      d('rr'),
    ];
    final out = _topoSort(graph(drafts))!;
    expect(out, hasLength(6));
    final indexOf = {for (var i = 0; i < out.length; i++) out[i]: i};
    for (final src in drafts) {
      for (final dst in src.draftRefIds) {
        expect(indexOf[dst]!, lessThan(indexOf[src.draftId]!),
            reason: '${src.draftId} → $dst edge must respect dep order');
      }
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Verbatim port of BrahmaCreateBloc._topoSort (Kahn's algorithm). Keep in
// sync with the production source if it ever changes; the test assertions
// remain valid because they pin the algorithm's contract, not its bytes.
// ─────────────────────────────────────────────────────────────────────────────
List<String>? _topoSort(Map<String, DraftEntity> nodes) {
  final indegree = <String, int>{for (final id in nodes.keys) id: 0};
  for (final d in nodes.values) {
    for (final ref in d.draftRefIds) {
      if (indegree.containsKey(ref)) {
        indegree[d.draftId] = (indegree[d.draftId] ?? 0) + 1;
      }
    }
  }
  final ready = [
    for (final e in indegree.entries)
      if (e.value == 0) e.key,
  ];
  final out = <String>[];
  while (ready.isNotEmpty) {
    final id = ready.removeLast();
    out.add(id);
    for (final other in nodes.values) {
      if (other.draftRefIds.contains(id) &&
          indegree.containsKey(other.draftId)) {
        indegree[other.draftId] = indegree[other.draftId]! - 1;
        if (indegree[other.draftId] == 0) ready.add(other.draftId);
      }
    }
  }
  if (out.length != nodes.length) return null;
  return out;
}
