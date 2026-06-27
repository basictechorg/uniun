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
}) =>
    GraphNodeData(
      eventId: id,
      content: '',
      eTagRefs: eTags,
      type: GraphNodeType.own,
      rootEventId: root,
      replyToEventId: reply,
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
}
