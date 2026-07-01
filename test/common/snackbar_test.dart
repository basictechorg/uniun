import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/snackbar.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Covers: error/success show message + use the right background color,
/// errorVia/successVia post on a captured messenger, no-op when no messenger.
void main() {
  testWidgets('AppSnackbar.error shows the message with error background',
      (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            return TextButton(
              onPressed: () => AppSnackbar.error(ctx, 'boom'),
              child: const Text('fire'),
            );
          }),
        ),
      ),
    );
    await t.tap(find.text('fire'));
    await t.pump();
    expect(find.text('boom'), findsOneWidget);
    final bar = t.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppColors.error);
    expect(bar.behavior, SnackBarBehavior.floating);
  });

  testWidgets('AppSnackbar.success uses primary, not error', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            return TextButton(
              onPressed: () => AppSnackbar.success(ctx, 'ok'),
              child: const Text('fire'),
            );
          }),
        ),
      ),
    );
    await t.tap(find.text('fire'));
    await t.pump();
    expect(find.text('ok'), findsOneWidget);
    final bar = t.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppColors.primary);
  });

  testWidgets('errorVia posts on the supplied messenger', (t) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await t.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    AppSnackbar.errorVia(messengerKey.currentState!, 'boom-via');
    await t.pump();
    expect(find.text('boom-via'), findsOneWidget);
  });

  testWidgets('successVia posts on the supplied messenger', (t) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await t.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    AppSnackbar.successVia(messengerKey.currentState!, 'ok-via');
    await t.pump();
    expect(find.text('ok-via'), findsOneWidget);
  });

  testWidgets(
      'calling error on a context whose maybeOf returns null is a no-op',
      (t) async {
    // No MaterialApp/Scaffold ancestor → ScaffoldMessenger.maybeOf returns null.
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (ctx) {
          AppSnackbar.error(ctx, 'silent');
          return const SizedBox();
        }),
      ),
    );
    await t.pump();
    expect(find.text('silent'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
