import 'dart:math' as math;

/// Tuning values for the force-directed graph layout — derived from the
/// node count so per-node area grows linearly with N and the visual density
/// stays constant as the graph scales. The constants here were chosen so the
/// graph at N≈12 matches the original hand-tuned look.
///
/// Pure functions, no Flutter dependency — kept here so they can be unit
/// tested independently of the [GraphCanvas] widget that consumes them.
class ForceLayoutTuning {
  const ForceLayoutTuning({
    required this.spreadScale,
    required this.linkDistance,
    required this.chargeStrength,
    required this.centerStrength,
    required this.collidePadding,
  });

  final double spreadScale;
  final double linkDistance;
  final double chargeStrength;
  final double centerStrength;
  final double collidePadding;

  /// Computes tuning constants for a graph of [nodeCount] nodes.
  ///
  /// - [spreadScale] grows with √(N/12), capped at √6 (≈2.45) so very large
  ///   graphs still settle in a finite viewport.
  /// - [linkDistance] and [chargeStrength] scale with [spreadScale] →
  ///   spacing ∝ spread, area ∝ spread² ∝ N ⇒ constant density.
  /// - [centerStrength] decays as N grows (with a floor) so the core
  ///   expands instead of compressing into a hairball.
  /// - [collidePadding] grows with density so labels never overlap.
  factory ForceLayoutTuning.forNodes(int nodeCount) {
    final t = (nodeCount / 12).clamp(1.0, 6.0);
    final spread = math.sqrt(t);
    return ForceLayoutTuning(
      spreadScale: spread,
      linkDistance: 190.0 * spread,
      chargeStrength: -4200.0 * spread,
      centerStrength: (0.03 / spread).clamp(0.008, 0.03),
      collidePadding: 6.0 + 6.0 * (spread - 1.0),
    );
  }
}

/// Node radius from incoming/outgoing connection count. Bounded so a single
/// hub doesn't blow up the canvas.
double nodeRadiusForConnections(int connections) {
  return (24.0 + connections * 3.0).clamp(24.0, 50.0);
}
