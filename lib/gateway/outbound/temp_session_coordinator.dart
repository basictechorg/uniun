import 'dart:async';

/// Manages the 5-minute TTL of ephemeral relay sessions.
///
/// Owns only timers — the actual session creation/removal is delegated to
/// [openIfMissing] and [closeNow]. This isolates the lifecycle policy from
/// the registry that owns the session map.
class TempSessionCoordinator {
  static const _ttl = Duration(minutes: 5);

  final void Function(String url) _openIfMissing;
  final void Function(String url) _closeNow;
  final Map<String, Timer> _timers = {};

  TempSessionCoordinator({
    required void Function(String url) openIfMissing,
    required void Function(String url) closeNow,
  })  : _openIfMissing = openIfMissing,
        _closeNow = closeNow;

  /// Create the session if missing, then (re)start its TTL timer.
  void touch(String url) {
    _openIfMissing(url);
    _timers[url]?.cancel();
    _timers[url] = Timer(_ttl, () => _expire(url));
  }

  void _expire(String url) {
    _closeNow(url);
    _timers.remove(url);
  }

  void disposeAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
