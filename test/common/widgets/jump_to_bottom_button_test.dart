import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/jump_to_bottom_button.dart';

/// Behaviour guard for the shared jump-to-latest affordance used by the chat
/// surfaces (channel feed, private channel, DM): it must invoke its callback
/// when shown, and must NOT absorb taps when hidden (so it never blocks the
/// message list underneath).
void main() {
  Widget host({required bool visible, required VoidCallback onPressed}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JumpToBottomButton(
            visible: visible,
            onPressed: onPressed,
            tooltip: 'Jump to latest',
          ),
        ),
      ),
    );
  }

  testWidgets('renders a down-chevron', (tester) async {
    await tester.pumpWidget(host(visible: true, onPressed: () {}));
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('invokes onPressed when visible and tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(visible: true, onPressed: () => taps++));
    await tester.tap(find.byType(JumpToBottomButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('ignores taps when hidden', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(visible: false, onPressed: () => taps++));
    // visible:false wraps the button in an IgnorePointer, so the tap should
    // fall through without firing the callback (warnIfMissed: the hit is
    // intentionally swallowed).
    await tester.tap(
      find.byType(JumpToBottomButton),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(taps, 0);
  });
}
