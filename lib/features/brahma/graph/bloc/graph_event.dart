part of 'graph_bloc.dart';

sealed class GraphEvent {
  const GraphEvent();
}

final class LoadGraphEvent extends GraphEvent {
  const LoadGraphEvent();
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
