import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/brahma/graph/layout/force_layout_tuning.dart';

/// Tests for the force-directed-layout tuning math extracted from
/// `graph_canvas.dart`. These pin the curves so an accidental tweak to the
/// magic numbers ("link distance is now 240 instead of 190") fails CI
/// instead of silently changing how every existing graph looks.
void main() {
  group('ForceLayoutTuning.forNodes', () {
    test('N=12 (sweet spot): spreadScale=1, original constants', () {
      final t = ForceLayoutTuning.forNodes(12);
      expect(t.spreadScale, closeTo(1.0, 1e-9));
      expect(t.linkDistance, closeTo(190.0, 1e-9));
      expect(t.chargeStrength, closeTo(-4200.0, 1e-9));
      expect(t.centerStrength, closeTo(0.03, 1e-9));
      expect(t.collidePadding, closeTo(6.0, 1e-9));
    });

    test('small N (<12) clamps to spreadScale=1', () {
      // 5 nodes still uses the base tuning — denser graphs don't shrink
      // the spacing below the design baseline.
      final t = ForceLayoutTuning.forNodes(5);
      expect(t.spreadScale, 1.0);
      expect(t.linkDistance, 190.0);
    });

    test('zero / negative N is safe and falls back to base tuning', () {
      final t0 = ForceLayoutTuning.forNodes(0);
      final tNeg = ForceLayoutTuning.forNodes(-5);
      expect(t0.spreadScale, 1.0);
      expect(tNeg.spreadScale, 1.0);
    });

    test('large N caps at √6 (≈2.449) — graph stays in viewport', () {
      final t = ForceLayoutTuning.forNodes(10000);
      expect(t.spreadScale, closeTo(math.sqrt(6), 1e-9));
      expect(t.linkDistance, closeTo(190.0 * math.sqrt(6), 1e-9));
    });

    test('spreadScale grows monotonically with N (no inversions)', () {
      var prev = ForceLayoutTuning.forNodes(1).spreadScale;
      for (var n = 1; n <= 100; n++) {
        final cur = ForceLayoutTuning.forNodes(n).spreadScale;
        expect(cur, greaterThanOrEqualTo(prev),
            reason: 'spread regressed at N=$n: $prev → $cur');
        prev = cur;
      }
    });

    test('centerStrength has a hard floor (0.008) so disconnected nodes do not drift forever', () {
      // Even at the max N, gravity never falls below the floor.
      final big = ForceLayoutTuning.forNodes(10000);
      expect(big.centerStrength, greaterThanOrEqualTo(0.008));
      // And never exceeds the ceiling at the small end.
      final small = ForceLayoutTuning.forNodes(1);
      expect(small.centerStrength, lessThanOrEqualTo(0.03));
    });

    test('collidePadding grows linearly with spread (denser → more whitespace)', () {
      final small = ForceLayoutTuning.forNodes(12);
      final big = ForceLayoutTuning.forNodes(72);
      expect(big.collidePadding, greaterThan(small.collidePadding));
    });

    test('density invariant: area per node ≈ constant across N', () {
      // area ∝ linkDistance² ∝ spread² ∝ N (per the design comment).
      // Verify the ratio holds within rounding noise.
      double areaPerNode(int n) {
        final t = ForceLayoutTuning.forNodes(n);
        return (t.linkDistance * t.linkDistance) / n;
      }

      // Below N=12 the clamp kicks in (spread=1 regardless of N), so density
      // does drop in that range — not part of the invariant. Test above 12.
      final ratio24 = areaPerNode(24) / areaPerNode(12);
      final ratio48 = areaPerNode(48) / areaPerNode(12);
      // Both should be ≈ 1.0 (area-per-node ≈ constant). Allow 5% wiggle.
      expect(ratio24, closeTo(1.0, 0.05));
      expect(ratio48, closeTo(1.0, 0.05));
    });
  });

  group('nodeRadiusForConnections', () {
    test('0 connections → minimum radius 24', () {
      expect(nodeRadiusForConnections(0), 24.0);
    });

    test('connections add 3px each, up to the 50px ceiling', () {
      expect(nodeRadiusForConnections(1), 27.0);
      expect(nodeRadiusForConnections(5), 39.0);
      expect(nodeRadiusForConnections(8), 48.0);
      // (24 + 9*3) = 51 → clamped to 50.
      expect(nodeRadiusForConnections(9), 50.0);
      expect(nodeRadiusForConnections(100), 50.0);
    });

    test('monotonically non-decreasing across connection counts', () {
      var prev = nodeRadiusForConnections(0);
      for (var c = 0; c < 50; c++) {
        final cur = nodeRadiusForConnections(c);
        expect(cur, greaterThanOrEqualTo(prev));
        prev = cur;
      }
    });
  });
}
