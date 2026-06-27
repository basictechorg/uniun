import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/safe_interactive_viewer.dart';

/// Reproduction + regression guard for the `InteractiveViewer` crash:
///
///   'package:flutter/.../interactive_viewer.dart': Failed assertion:
///   'scale != 0.0': is not true.
///
/// Root cause: during a pinch, when the two pointers' span collapses to zero
/// (e.g. the iOS-simulator Option-pinch sweeps both synthetic touches through
/// the centre), `ScaleUpdateDetails.scale` becomes `0.0`. The framework's
/// `_onScaleUpdate` then feeds a `0.0` scale change into `_matrixScale`, which
/// trips `assert(scale != 0.0)`.
void main() {
  // Drive two pointers from opposite sides INTO the same point, forcing the
  // gesture span — and therefore `details.scale` — to collapse to 0.
  Future<void> convergePinch(WidgetTester tester, Offset centre) async {
    final p1 = await tester.startGesture(centre + const Offset(-60, 0), pointer: 1);
    final p2 = await tester.startGesture(centre + const Offset(60, 0), pointer: 2);
    // Step the pointers together so the scale recogniser engages, then land
    // both exactly on `centre` (span == 0 -> details.scale == 0).
    for (final t in [0.5, 0.85, 1.0]) {
      await p1.moveTo(centre + Offset(-60 * (1 - t), 0));
      await p2.moveTo(centre + Offset(60 * (1 - t), 0));
      await tester.pump();
    }
    await p1.up();
    await p2.up();
    await tester.pump();
  }

  testWidgets('stock InteractiveViewer throws on a convergent pinch (the bug)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveViewer(
            constrained: false,
            minScale: 0.3,
            maxScale: 4.0,
            child: const SizedBox(width: 800, height: 800),
          ),
        ),
      ),
    );

    await convergePinch(tester, const Offset(400, 400));

    // The framework assertion fires during the gesture.
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('SafeInteractiveViewer survives a convergent pinch (the fix)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeInteractiveViewer(
            constrained: false,
            minScale: 0.3,
            maxScale: 4.0,
            child: SizedBox(width: 800, height: 800),
          ),
        ),
      ),
    );

    await convergePinch(tester, const Offset(400, 400));

    // No assertion, no exception — the degenerate gesture is guarded.
    expect(tester.takeException(), isNull);
    expect(find.byType(SafeInteractiveViewer), findsOneWidget);
  });

  group('computeScaleChange (root-cause guard)', () {
    test('a zero gesture scale is a no-op (1.0), never 0', () {
      expect(
        SafeInteractiveViewer.computeScaleChange(
          currentScale: 1.0,
          scaleStart: 1.0,
          gestureScale: 0.0,
          minScale: 0.3,
          maxScale: 4.0,
        ),
        1.0,
      );
    });

    test('a non-finite gesture scale is a no-op (1.0)', () {
      for (final bad in [double.infinity, double.nan, -double.infinity]) {
        expect(
          SafeInteractiveViewer.computeScaleChange(
            currentScale: 1.0,
            scaleStart: 1.0,
            gestureScale: bad,
            minScale: 0.3,
            maxScale: 4.0,
          ),
          1.0,
        );
      }
    });

    test('a normal pinch scales by the expected, clamped ratio', () {
      // Want 2x from a 1x start -> change of 2.0.
      expect(
        SafeInteractiveViewer.computeScaleChange(
          currentScale: 1.0,
          scaleStart: 1.0,
          gestureScale: 2.0,
          minScale: 0.3,
          maxScale: 4.0,
        ),
        2.0,
      );
      // Desired 8x is clamped to maxScale 4.0 -> change of 4.0 from 1x.
      expect(
        SafeInteractiveViewer.computeScaleChange(
          currentScale: 1.0,
          scaleStart: 1.0,
          gestureScale: 8.0,
          minScale: 0.3,
          maxScale: 4.0,
        ),
        4.0,
      );
    });
  });
}
