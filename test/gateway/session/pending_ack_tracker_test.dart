import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/gateway/session/pending_ack_tracker.dart';

/// Covers: PendingAckTracker's arm/release/clear state machine — the
/// starting empty state, arming sets both id fields, release only succeeds
/// on a matching eventId (returning the queueId and clearing state) and is
/// a no-op mismatch otherwise, and clear unconditionally resets.
void main() {
  test('starts with no pending slot', () {
    final t = PendingAckTracker();
    expect(t.hasPending, isFalse);
    expect(t.eventId, isNull);
    expect(t.queueId, isNull);
  });

  test('arm sets the pending eventId/queueId', () {
    final t = PendingAckTracker()..arm('e1', 42);
    expect(t.hasPending, isTrue);
    expect(t.eventId, 'e1');
    expect(t.queueId, 42);
  });

  test('release with a matching eventId returns the queueId and clears '
      'state', () {
    final t = PendingAckTracker()..arm('e1', 42);
    final released = t.release('e1');
    expect(released, 42);
    expect(t.hasPending, isFalse);
    expect(t.eventId, isNull);
    expect(t.queueId, isNull);
  });

  test('release with a mismatched eventId returns null and leaves state '
      'untouched', () {
    final t = PendingAckTracker()..arm('e1', 42);
    final released = t.release('someone-else');
    expect(released, isNull);
    expect(t.hasPending, isTrue);
    expect(t.eventId, 'e1');
    expect(t.queueId, 42);
  });

  test('release with nothing armed returns null', () {
    final t = PendingAckTracker();
    expect(t.release('e1'), isNull);
  });

  test('clear resets an armed slot', () {
    final t = PendingAckTracker()..arm('e1', 42);
    t.clear();
    expect(t.hasPending, isFalse);
    expect(t.eventId, isNull);
    expect(t.queueId, isNull);
  });

  test('clear on an already-empty tracker is a harmless no-op', () {
    final t = PendingAckTracker();
    expect(t.clear, returnsNormally);
    expect(t.hasPending, isFalse);
  });

  test('re-arming after a release overwrites the slot', () {
    final t = PendingAckTracker()..arm('e1', 1);
    t.release('e1');
    t.arm('e2', 2);
    expect(t.eventId, 'e2');
    expect(t.queueId, 2);
  });
}
