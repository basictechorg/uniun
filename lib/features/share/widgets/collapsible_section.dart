import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// InkWell header + AnimatedRotation chevron + AnimatedCrossFade body.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.label,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String label;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
    value: widget.initiallyExpanded ? 1 : 0,
  );
  late final Animation<double> _sizeFactor =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Vertical accordion — clip height only. AnimatedCrossFade animated both
        // axes, which made the body appear to grow horizontally from center.
        SizeTransition(
          alignment: Alignment.topCenter,
          sizeFactor: _sizeFactor,
          child: widget.child,
        ),
      ],
    );
  }
}
