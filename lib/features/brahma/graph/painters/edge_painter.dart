import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

/// Paints edges between graph nodes, highlighting connections to the selected node.
///
/// Colours are resolved by the caller (has BuildContext) and passed in so
/// this painter stays context-free.
class EdgePainter extends CustomPainter {
  const EdgePainter({
    required this.graph,
    required this.selectedNodeId,
    required this.restColor,
    required this.highlightColor,
    this.dim = false,
  });

  final Graph graph;
  final String? selectedNodeId;
  final Color restColor;
  final Color highlightColor;

  /// When true (graph search active), all edges fade back so the matched
  /// nodes carry the focus.
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in graph.edges) {
      final srcId = edge.source.key!.value as String;
      final destId = edge.destination.key!.value as String;

      final srcCenter = Offset(
        edge.source.x + edge.source.width / 2,
        edge.source.y + edge.source.height / 2,
      );
      final destCenter = Offset(
        edge.destination.x + edge.destination.width / 2,
        edge.destination.y + edge.destination.height / 2,
      );

      final isHighlighted = selectedNodeId != null &&
          (srcId == selectedNodeId || destId == selectedNodeId);
      final hasSelection = selectedNodeId != null;

      // Mono-blue graph (DESIGN.md §2.2): neutral-300 edges at rest so the blue
      // nodes carry the accent; the focused node's edges light up in primary.
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.5 : 1.6
        ..color = dim
            ? restColor.withValues(alpha: 0.25)
            : isHighlighted
                ? highlightColor.withValues(alpha: 0.55)
                : hasSelection
                    ? restColor.withValues(alpha: 0.4)
                    : restColor;

      canvas.drawLine(srcCenter, destCenter, paint);
    }
  }

  @override
  bool shouldRepaint(EdgePainter old) => true;
}
