import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/features/brahma/graph/models/graph_node_type.dart';

/// A graph node carrying NIP-10 threading markers, the way GraphBloc builds it
/// from a NoteEntity / SavedNoteEntity / DraftEntity.
GraphNodeData _node(
  String id, {
  String? root,
  String? reply,
  List<String> eTags = const [],
  List<String> draftRefIds = const [],
  GraphNodeType type = GraphNodeType.own,
}) =>
    GraphNodeData(
      eventId: id,
      content: '',
      eTagRefs: eTags,
      type: type,
      rootEventId: root,
      replyToEventId: reply,
      draftRefIds: draftRefIds,
    );

void main() {
  group('GraphNodeData.refEdges (canonical reply/reference rule)', () {
    test('excludes the NIP-10 thread root marker', () {
      // A nested reply: root R, direct parent P, plus a genuine mention M.
      final n = _node('child', root: 'R', reply: 'P', eTags: ['R', 'P', 'M']);
      // Root is dropped so deep replies do not link to the thread root.
      expect(n.refEdges, {'P', 'M'});
    });

    test('top-level note keeps all e-tag mentions', () {
      final n = _node('x', eTags: ['A', 'B']);
      expect(n.refEdges, {'A', 'B'});
    });

    test('direct reply to the root still links to the root (its parent)', () {
      // P replies directly to R: reply == root == R. R is P's genuine parent.
      final p = _node('P', root: 'R', reply: 'R', eTags: ['R']);
      expect(p.refEdges, {'R'});
    });
  });

  group('GraphBloc.buildAdjacency', () {
    test('a genuine reference is exactly one bidirectional edge', () {
      final adj = GraphBloc.buildAdjacency([
        _node('A', eTags: ['B']), // A mentions B
        _node('B'),
      ]);
      expect(adj['A'], {'B'});
      expect(adj['B'], {'A'});
    });

    test('thread root is NOT a hub of every descendant reply', () {
      // R is the root. P is a direct reply to R. C is a reply to P (nested),
      // so C e-tags both R (root) and P (reply).
      final adj = GraphBloc.buildAdjacency([
        _node('R'),
        _node('P', root: 'R', reply: 'R', eTags: ['R']),
        _node('C', root: 'R', reply: 'P', eTags: ['R', 'P']),
      ]);
      // Root links only to its DIRECT reply P — never to the nested C.
      expect(adj['R'], {'P'});
      expect(adj['P'], {'R', 'C'});
      // C links to its parent P, NOT to the thread root R (the old bug).
      expect(adj['C'], {'P'});
    });

    test('edges only form between nodes present in the visible set', () {
      // A references B and an off-graph note Z; only B is in the node set.
      final adj = GraphBloc.buildAdjacency([
        _node('A', eTags: ['B', 'Z']),
        _node('B'),
      ]);
      expect(adj['A'], {'B'});
      expect(adj['B'], {'A'});
    });
  });

  // ── Draft-only nodes: draftRefIds form edges between draft UUIDs ─────────

  group('Draft → draft edges via draftRefIds', () {
    test('a single draft → draft ref shows up as a bidirectional edge', () {
      final adj = GraphBloc.buildAdjacency([
        _node('parent-uuid',
            type: GraphNodeType.draft, draftRefIds: ['child-uuid']),
        _node('child-uuid', type: GraphNodeType.draft),
      ]);
      expect(adj['parent-uuid'], {'child-uuid'});
      expect(adj['child-uuid'], {'parent-uuid'});
    });

    test('mixed: a draft refs another draft AND a published note (e-tag)', () {
      // parent draft: draftRefIds=[child], eTags=[real-note] (top-level so no
      // root/reply markers — refEdges keeps all e-tags + all draftRefIds).
      final adj = GraphBloc.buildAdjacency([
        _node('parent',
            type: GraphNodeType.draft,
            draftRefIds: ['child'],
            eTags: ['real-note']),
        _node('child', type: GraphNodeType.draft),
        _node('real-note', type: GraphNodeType.own),
      ]);
      expect(adj['parent'], {'child', 'real-note'});
      expect(adj['child'], {'parent'});
      expect(adj['real-note'], {'parent'});
    });

    test('draft ref to a UUID NOT in the visible set is dropped', () {
      // child UUID isn't part of the rendered graph (filtered out by Manas
      // scope, say). The edge silently disappears — same rule as e-tag refs
      // to off-graph notes.
      final adj = GraphBloc.buildAdjacency([
        _node('parent',
            type: GraphNodeType.draft, draftRefIds: ['ghost']),
      ]);
      expect(adj['parent'], isEmpty);
    });

    test('diamond draft graph A → {B, C} → D collapses to 4 nodes / 4 unique edges', () {
      final adj = GraphBloc.buildAdjacency([
        _node('A', type: GraphNodeType.draft, draftRefIds: ['B', 'C']),
        _node('B', type: GraphNodeType.draft, draftRefIds: ['D']),
        _node('C', type: GraphNodeType.draft, draftRefIds: ['D']),
        _node('D', type: GraphNodeType.draft),
      ]);
      expect(adj['A'], {'B', 'C'});
      expect(adj['B'], {'A', 'D'});
      expect(adj['C'], {'A', 'D'});
      expect(adj['D'], {'B', 'C'});
    });

    test('refEdges merges e-tags (minus root) AND draftRefIds for a single node', () {
      // Deep reply with a parent + a mention + a draft ref.
      final n = _node('child',
          type: GraphNodeType.draft,
          root: 'R',
          reply: 'P',
          eTags: ['R', 'P', 'M'],
          draftRefIds: ['draft-uuid']);
      // Root R is dropped (per the canonical reply rule); P, M, and the
      // draft UUID all stay.
      expect(n.refEdges, {'P', 'M', 'draft-uuid'});
    });
  });
}
