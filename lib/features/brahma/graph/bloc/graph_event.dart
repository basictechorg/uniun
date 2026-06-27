part of 'graph_bloc.dart';

sealed class GraphEvent {
  const GraphEvent();
}

final class LoadGraphEvent extends GraphEvent {
  const LoadGraphEvent({this.manasId, this.manasName});

  /// When non-null, scopes the graph to the membership of this Manas.
  /// Null = full Brahma graph (default).
  final String? manasId;

  /// Display name of the scoped Manas, used by the header. Optional —
  /// when null the header falls back to a generic label.
  final String? manasName;
}

/// Tap a node — if already selected, deselects it.
final class SelectGraphNodeEvent extends GraphEvent {
  const SelectGraphNodeEvent(this.nodeId);
  final String nodeId;
}

final class DeselectGraphNodeEvent extends GraphEvent {
  const DeselectGraphNodeEvent();
}

/// Delete a draft node from the graph (and from Isar).
final class DeleteDraftNodeEvent extends GraphEvent {
  const DeleteDraftNodeEvent(this.draftId);
  final String draftId;
}

/// Filter the graph by a free-text query — matching nodes stay lit, the rest
/// dim. An empty/blank query clears the search.
final class SearchGraphEvent extends GraphEvent {
  const SearchGraphEvent(this.query);
  final String query;
}
