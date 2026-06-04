import 'dart:async';

/// Lightweight cancellation primitive shared across LLM backends.
///
/// Each `sendChat` / `generateOneShot` call receives a token. Calling
/// [cancel] on the token from the caller signals the backend to abort
/// whatever native or HTTP work is in flight.
///
/// Backends must check [isCancelled] at safe points (token boundaries,
/// stream-event boundaries) and tear down cleanly.
class LlmCancellationToken {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Future that completes when [cancel] is called. Backends can `await`
  /// or `Future.any` this to interleave with native streams.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_completer.isCompleted) return;
    _completer.complete();
  }
}
