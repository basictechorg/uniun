import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/drop_icon.dart';
/// Branded loading indicator — a gently pulsing [DropIcon] used everywhere in
/// place of [CircularProgressIndicator]. The drop scales and fades on a loop to
/// signal work in progress. Defaults to [Theme.of(context).colorScheme.primary].
class DropLoadingIndicator extends StatefulWidget {
  const DropLoadingIndicator({super.key, this.size = 80, this.color});

  /// Box size handed to [DropIcon] (the visible drop is smaller than this due
  /// to the glyph's viewBox padding).
  final double size;

  /// Drop colour; falls back to [Theme.of(context).colorScheme.primary] when null.
  final Color? color;

  @override
  State<DropLoadingIndicator> createState() => _DropLoadingIndicatorState();
}

class _DropLoadingIndicatorState extends State<DropLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  static final Animatable<double> _scale =
      Tween<double>(begin: 1.0, end: 0.82)
          .chain(CurveTween(curve: Curves.easeInOut));
  static final Animatable<double> _opacity =
      Tween<double>(begin: 1.0, end: 0.35)
          .chain(CurveTween(curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller.drive(_scale),
      child: FadeTransition(
        opacity: _controller.drive(_opacity),
        child: DropIcon(
          size: widget.size,
          color: widget.color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
