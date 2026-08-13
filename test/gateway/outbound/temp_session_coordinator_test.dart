import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/gateway/outbound/temp_session_coordinator.dart';

/// Covers: TempSessionCoordinator's touch() (opens the session, arms a
/// fresh 5-minute TTL, re-touching before expiry cancels + restarts the
/// timer rather than expiring), the timer firing closeNow() + clearing its
/// slot once the TTL elapses, independent per-url timers, and disposeAll()
/// cancelling every outstanding timer so none of them fire afterward.
void main() {
  test('touch opens the session immediately', () {
    fakeAsync((async) {
      final opened = <String>[];
      final coordinator = TempSessionCoordinator(
        openIfMissing: opened.add,
        closeNow: (_) {},
      );

      coordinator.touch('wss://r1');

      expect(opened, ['wss://r1']);
    });
  });

  test('the session is closed once the 5-minute TTL elapses', () {
    fakeAsync((async) {
      final closed = <String>[];
      final coordinator = TempSessionCoordinator(
        openIfMissing: (_) {},
        closeNow: closed.add,
      );

      coordinator.touch('wss://r1');
      async.elapse(const Duration(minutes: 5));

      expect(closed, ['wss://r1']);
    });
  });

  test('a touch just before the TTL elapses restarts the timer instead of '
      'expiring', () {
    fakeAsync((async) {
      final closed = <String>[];
      final opened = <String>[];
      final coordinator = TempSessionCoordinator(
        openIfMissing: opened.add,
        closeNow: closed.add,
      );

      coordinator.touch('wss://r1');
      async.elapse(const Duration(minutes: 4));
      coordinator.touch('wss://r1'); // re-arm before expiry

      async.elapse(const Duration(minutes: 4));
      expect(closed, isEmpty); // still within the renewed window

      async.elapse(const Duration(minutes: 1));
      expect(closed, ['wss://r1']);
      expect(opened, ['wss://r1', 'wss://r1']);
    });
  });

  test('each url gets its own independent TTL timer', () {
    fakeAsync((async) {
      final closed = <String>[];
      final coordinator = TempSessionCoordinator(
        openIfMissing: (_) {},
        closeNow: closed.add,
      );

      coordinator.touch('wss://r1');
      async.elapse(const Duration(minutes: 2));
      coordinator.touch('wss://r2');

      async.elapse(const Duration(minutes: 3)); // r1 hits 5min, r2 at 3min
      expect(closed, ['wss://r1']);

      async.elapse(const Duration(minutes: 2)); // r2 hits 5min
      expect(closed, ['wss://r1', 'wss://r2']);
    });
  });

  test('disposeAll cancels every outstanding timer — nothing fires '
      'afterward', () {
    fakeAsync((async) {
      final closed = <String>[];
      final coordinator = TempSessionCoordinator(
        openIfMissing: (_) {},
        closeNow: closed.add,
      );

      coordinator.touch('wss://r1');
      coordinator.touch('wss://r2');
      coordinator.disposeAll();

      async.elapse(const Duration(minutes: 10));

      expect(closed, isEmpty);
    });
  });

  test('an expired timer clears its own slot, so a fresh touch after '
      'expiry re-opens cleanly', () {
    fakeAsync((async) {
      final opened = <String>[];
      final closed = <String>[];
      final coordinator = TempSessionCoordinator(
        openIfMissing: opened.add,
        closeNow: closed.add,
      );

      coordinator.touch('wss://r1');
      async.elapse(const Duration(minutes: 5));
      expect(closed, ['wss://r1']);

      coordinator.touch('wss://r1');
      async.elapse(const Duration(minutes: 5));
      expect(closed, ['wss://r1', 'wss://r1']);
      expect(opened, ['wss://r1', 'wss://r1']);
    });
  });
}
