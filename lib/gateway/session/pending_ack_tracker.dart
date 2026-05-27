/// Tracks the single in-flight outbound event awaiting an ["OK"] from the relay.
///
/// One per [RelaySession]. Only one event is in-flight at a time — this mirrors
/// today's `_pendingEventId`/`_pendingQueueId` pair on WebSocketService.
class PendingAckTracker {
  String? _eventId;
  int? _queueId;

  bool get hasPending => _eventId != null;
  String? get eventId => _eventId;
  int? get queueId => _queueId;

  void arm(String eventId, int queueId) {
    _eventId = eventId;
    _queueId = queueId;
  }

  /// Returns the queueId of the released slot, or null if [eventId] didn't match.
  int? release(String eventId) {
    if (_eventId != eventId) return null;
    final q = _queueId;
    _eventId = null;
    _queueId = null;
    return q;
  }

  void clear() {
    _eventId = null;
    _queueId = null;
  }
}
