import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Draws an evenly-spaced dot grid as the graph background.
class DotPatternPainter extends CustomPainter {
  const DotPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.4)
      ..strokeCap = StrokeCap.round;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter old) => false;
}
