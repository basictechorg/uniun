import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Draws an evenly-spaced dot grid as the graph background.
class DotPatternPainter extends CustomPainter {
  const DotPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Faint neutral-200 dot grid (DESIGN.md §2.2): small dots on an 18px grid.
    final paint = Paint()
      ..color = AppColors.border
      ..strokeCap = StrokeCap.round;
    const spacing = 18.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter old) => false;
}
