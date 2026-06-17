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
    this.scopedManasColorHexes = const <String>[],
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

  /// Palette chosen by the user for the scoped Manas (1–3 hex strings).
  /// Empty when unscoped, or when scoped to a Manas with no palette set
  /// (header falls back to the default legend in both cases).
  final List<String> scopedManasColorHexes;

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
    List<String>? scopedManasColorHexes,
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
      scopedManasColorHexes: clearScope
          ? const <String>[]
          : (scopedManasColorHexes ?? this.scopedManasColorHexes),
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
