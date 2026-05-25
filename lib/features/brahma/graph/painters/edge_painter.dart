import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Paints edges between graph nodes, highlighting connections to the selected node.
class EdgePainter extends CustomPainter {
  const EdgePainter({required this.graph, required this.selectedNodeId});

  final Graph graph;
  final String? selectedNodeId;

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

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.5 : 1.2
        ..color = isHighlighted
            ? AppColors.primary.withValues(alpha: 0.9)
            : hasSelection
                ? AppColors.outline.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.3);

      canvas.drawLine(srcCenter, destCenter, paint);
    }
  }

  @override
  bool shouldRepaint(EdgePainter old) => true;
}
