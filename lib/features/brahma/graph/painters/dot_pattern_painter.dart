import 'package:flutter/material.dart';

/// Draws an evenly-spaced dot grid as the graph background.
///
/// Colour is captured at construction so this painter stays context-free —
/// the caller resolves `context.custom.graphDotPattern` and passes it in.
class DotPatternPainter extends CustomPainter {
  const DotPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Faint neutral-200 dot grid (DESIGN.md §2.2): small dots on an 18px grid.
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    const spacing = 18.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter old) => old.color != color;
}
