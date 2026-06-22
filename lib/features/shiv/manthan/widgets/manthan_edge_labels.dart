import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Renders the four directional action labels around the swipe card area.
///
/// Labels fade in proportionally as [drag] moves toward that edge.
/// The active direction's label becomes full primary-blue at the threshold.
class ManthanEdgeLabels extends StatelessWidget {
  const ManthanEdgeLabels({super.key, required this.drag});

  /// Current drag offset of the active card. Used to compute per-edge opacity.
  final Offset drag;

  static const double _threshold = 90;
  static const double _minOpacity = 0.25;

  static const double _activeThreshold = 30;

  double _opacityFor(double value) {
    if (value <= 0) return 0;
    return (_minOpacity + (1 - _minOpacity) * (value / _threshold)).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Dominant-axis formula: exactly one edge can be active at a time.
    final horizontal = _drag.dx.abs() > _drag.dy.abs();
    final rightActive = horizontal && _drag.dx > _activeThreshold;
    final leftActive = horizontal && _drag.dx < -_activeThreshold;
    final downActive = !horizontal && _drag.dy > _activeThreshold;
    final upActive = !horizontal && _drag.dy < -_activeThreshold;

    // Opacity: fade in proportionally along each axis independently.
    final hOpacity = _opacityFor(_drag.dx.abs());
    final vOpacity = _opacityFor(_drag.dy.abs());

    return Stack(
      children: [
        // Top — Publish (swipe up)
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Center(
            child: _EdgeLabel(
              label: l10n.manthanEdgePublish.toUpperCase(),
              prefix: '↑',
              opacity: vOpacity * (_drag.dy < 0 ? 1 : 0),
              active: upActive,
            ),
          ),
        ),
        // Bottom — Discuss (swipe down)
        Positioned(
          bottom: 118,
          left: 0,
          right: 0,
          child: Center(
            child: _EdgeLabel(
              label: l10n.manthanEdgeDiscuss.toUpperCase(),
              prefix: '↓',
              opacity: vOpacity * (_drag.dy > 0 ? 1 : 0),
              active: downActive,
            ),
          ),
        ),
        // Left — Discard (swipe left)
        Positioned(
          left: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: _EdgeLabel(
                label: l10n.manthanEdgeDiscard.toUpperCase(),
                prefix: '←',
                opacity: hOpacity * (_drag.dx < 0 ? 1 : 0),
                active: leftActive,
              ),
            ),
          ),
        ),
        // Right — Draft (swipe right)
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: _EdgeLabel(
                label: l10n.manthanEdgeDraft.toUpperCase(),
                prefix: '→',
                opacity: hOpacity * (_drag.dx > 0 ? 1 : 0),
                active: rightActive,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Expose drag as a computed-safe copy.
  Offset get _drag => drag;
}

class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({
    required this.label,
    required this.prefix,
    required this.opacity,
    required this.active,
  });

  final String label;
  final String prefix;
  final double opacity;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Text(
        '$prefix $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: active ? AppColors.primary : AppColors.outlineVariant,
        ),
      ),
    );
  }
}
