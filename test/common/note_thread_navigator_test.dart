import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/note_thread_navigator.dart';

/// Shim must delegate to openAsNote exactly once and await it; errors propagate.
void main() {
  testWidgets('invokes openAsNote exactly once and awaits it', (tester) async {
    var calls = 0;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (ctx) {
          return TextButton(
            onPressed: () async {
              await openEventThread(
                ctx,
                'event-id',
                openAsNote: () async {
                  calls++;
                  await Future<void>.delayed(const Duration(milliseconds: 1));
                  completed = true;
                },
              );
            },
            child: const Text('go'),
          );
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(completed, isTrue,
        reason: 'shim must AWAIT openAsNote, not fire-and-forget');
  });

  testWidgets('propagates errors from openAsNote', (tester) async {
    Object? caught;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (ctx) {
          return TextButton(
            onPressed: () async {
              try {
                await openEventThread(
                  ctx,
                  'e',
                  openAsNote: () async => throw StateError('boom'),
                );
              } catch (e) {
                caught = e;
              }
            },
            child: const Text('go'),
          );
        }),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(caught, isA<StateError>());
  });
}
