part of 'graph_bloc.dart';

enum GraphStatus { initial, loading, loaded, error }

class GraphState {
  const GraphState({
    this.status = GraphStatus.initial,
    this.nodes = const [],
    this.adjacency = const {},
    this.profiles = const {},
    this.selectedNodeId,
    this.errorMessage,
    this.scopedManasId,
    this.scopedManasName,
    this.scopedManasIconName,
  });

  final GraphStatus status;

  /// All graph nodes (saved notes, own notes, drafts).
  final List<GraphNodeData> nodes;

  /// Bidirectional adjacency: nodeId → set of connected nodeIds.
  final Map<String, Set<String>> adjacency;

  /// pubkeyHex → ProfileEntity for node author display.
  final Map<String, ProfileEntity> profiles;

  /// The currently selected node id, null = nothing selected.
  final String? selectedNodeId;

  final String? errorMessage;

  /// When non-null, the graph is scoped to this Manas's membership.
  /// Null = full Brahma graph (default).
  final String? scopedManasId;

  /// Display name of the scoped Manas (for the header). May be null even
  /// when [scopedManasId] is set (loaded without a name hint).
  final String? scopedManasName;

  /// Icon name (key into `ManasIcons.all`) for the scoped Manas. Null
  /// when unscoped or when the Manas has no chosen icon — header falls
  /// back to `ManasIcons.fallback`.
  final String? scopedManasIconName;

  GraphState copyWith({
    GraphStatus? status,
    List<GraphNodeData>? nodes,
    Map<String, Set<String>>? adjacency,
    Map<String, ProfileEntity>? profiles,
    String? selectedNodeId,
    bool clearSelection = false,
    String? errorMessage,
    String? scopedManasId,
    String? scopedManasName,
    String? scopedManasIconName,
    bool clearScope = false,
  }) {
    return GraphState(
      status: status ?? this.status,
      nodes: nodes ?? this.nodes,
      adjacency: adjacency ?? this.adjacency,
      profiles: profiles ?? this.profiles,
      selectedNodeId:
          clearSelection ? null : (selectedNodeId ?? this.selectedNodeId),
      errorMessage: errorMessage ?? this.errorMessage,
      scopedManasId:
          clearScope ? null : (scopedManasId ?? this.scopedManasId),
      scopedManasName:
          clearScope ? null : (scopedManasName ?? this.scopedManasName),
      scopedManasIconName: clearScope
          ? null
          : (scopedManasIconName ?? this.scopedManasIconName),
    );
  }

  GraphNodeData? get selectedNode {
    if (selectedNodeId == null) return null;
    try {
      return nodes.firstWhere((n) => n.eventId == selectedNodeId);
    } catch (_) {
      return null;
    }
  }

  bool isConnectedToSelected(String nodeId) {
    if (selectedNodeId == null) return false;
    return adjacency[selectedNodeId]?.contains(nodeId) ?? false;
  }
}
