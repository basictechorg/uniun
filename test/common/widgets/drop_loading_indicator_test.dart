import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';

/// Covers: scale+fade transition composition, animation ticks across
/// frames, size prop reaches DropIcon, AnimationController dispose.
void main() {
  Finder scaleIn() => find.descendant(
        of: find.byType(DropLoadingIndicator),
        matching: find.byType(ScaleTransition),
      );
  Finder fadeIn() => find.descendant(
        of: find.byType(DropLoadingIndicator),
        matching: find.byType(FadeTransition),
      );

  testWidgets('renders a ScaleTransition + FadeTransition composition',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: DropLoadingIndicator()),
    ));
    await t.pump(const Duration(milliseconds: 100));
    expect(scaleIn(), findsOneWidget);
    expect(fadeIn(), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('animation continues across frames (ticker is running)',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: DropLoadingIndicator()),
    ));
    final scale1 = t.widget<ScaleTransition>(scaleIn()).scale.value;
    await t.pump(const Duration(milliseconds: 250));
    final scale2 = t.widget<ScaleTransition>(scaleIn()).scale.value;
    expect(scale1, isNot(scale2),
        reason: 'pulsing animation must change scale value between frames');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('size prop sizes the SvgPicture via DropIcon', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: DropLoadingIndicator(size: 120)),
    ));
    await t.pump(const Duration(milliseconds: 50));
    // The SvgPicture inside DropIcon should receive width=120.
    final sized = t.widget<SizedBox>(find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 120 && w.height == 120,
    ));
    expect(sized.width, 120);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('disposes cleanly when removed from the tree', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: DropLoadingIndicator()),
    ));
    await t.pump(const Duration(milliseconds: 50));
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox()),
    ));
    expect(t.takeException(), isNull,
        reason: 'AnimationController must be disposed in dispose()');
  });
}
