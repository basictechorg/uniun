import 'dart:async';
import 'dart:collection';

import 'package:injectable/injectable.dart';

/// Bounded-concurrency lane for the embedding model.
///
/// The embedder (`flutter_gemma_embeddings`) is a small dedicated model on a
/// separate chip path — it does NOT contend with the main chat model loaded
/// in [AIModelRunner]. So it's not on [InferenceScheduler]. The only thing
/// this queue prevents is a CPU storm when a relay flood spawns dozens of
/// concurrent `embed()` calls.
///
/// `Semaphore(2)` is empirically enough to keep the embedder saturated on a
/// midrange phone while leaving headroom for the chat model. See
/// `docs/SHIVA/scheduling.md` §7.
@lazySingleton
class EmbeddingQueue {
  static const _maxConcurrent = 2;

  int _inFlight = 0;
  final Queue<Completer<void>> _waiters = Queue();

  /// Runs [work] with at most [_maxConcurrent] in flight at a time.
  Future<T> run<T>(Future<T> Function() work) async {
    await _acquire();
    try {
      return await work();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_inFlight < _maxConcurrent) {
      _inFlight++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    if (_inFlight > 0) _inFlight--;
  }
}
