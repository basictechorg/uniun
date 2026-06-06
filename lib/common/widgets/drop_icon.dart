import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shiv AI assistant glyph — the drop mark used wherever the assistant is
/// represented (avatars, headers, empty states).
class DropIcon extends StatelessWidget {
  const DropIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/drop.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
