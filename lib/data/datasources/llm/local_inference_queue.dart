import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Serializes all on-device LLM access with two priority lanes.
///
/// flutter_gemma's native MediaPipe session can run only one inference at a
/// time. Without coordination, background graph-extraction jobs collide with
/// the user-facing Shiv chat — chat gets cancelled or waits behind a long
/// queue of saves. This queue guarantees:
///
///   - Chat turns ([runHigh]) always cut in front of extraction jobs.
///   - Extraction jobs ([runLow]) run one at a time, only when no chat is
///     pending. Any extraction submitted during a chat turn waits.
///   - We cannot preempt MediaPipe mid-inference, so a chat turn waits at
///     most one in-flight extraction.
@lazySingleton
class ModelTaskQueue {
  final Queue<_Task> _high = Queue();
  final Queue<_Task> _low = Queue();
  bool _running = false;

  /// While true, low-priority (extraction) tasks remain queued but are not
  /// dispatched. Used by [ShivAIBloc] so the AI tab can fully own the model
  /// — user is here, chat may arrive at any moment, no background graph
  /// work should fight for the GPU. Resumes when the user leaves the tab.
  bool _lowPriorityPaused = false;

  void pauseLowPriority() {
    if (_lowPriorityPaused) return;
    debugPrint('⏸️ ModelTaskQueue: low-priority paused');
    _lowPriorityPaused = true;
  }

  void resumeLowPriority() {
    if (!_lowPriorityPaused) return;
    debugPrint('▶️  ModelTaskQueue: low-priority resumed '
        '(pending low=${_low.length})');
    _lowPriorityPaused = false;
    _kick();
  }

  Future<T> runHigh<T>(Future<T> Function() task, {String label = 'chat'}) {
    return _enqueue(task, _high, label);
  }

  Future<T> runLow<T>(Future<T> Function() task, {String label = 'extract'}) {
    return _enqueue(task, _low, label);
  }

  Future<T> _enqueue<T>(
      Future<T> Function() task, Queue<_Task> lane, String label) {
    final completer = Completer<T>();
    lane.add(_Task(label, () async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }));
    _kick();
    return completer.future;
  }

  void _kick() {
    if (_running) return;
    _running = true;
    Future.microtask(_drain);
  }

  Future<void> _drain() async {
    while (true) {
      _Task? task;
      if (_high.isNotEmpty) {
        task = _high.removeFirst();
      } else if (!_lowPriorityPaused && _low.isNotEmpty) {
        task = _low.removeFirst();
      }
      if (task == null) break;
      debugPrint('🔀 ModelTaskQueue: running ${task.label} '
          '(pending high=${_high.length} low=${_low.length} '
          'paused=$_lowPriorityPaused)');
      await task.run();
    }
    _running = false;
  }
}

class _Task {
  _Task(this.label, this.run);
  final String label;
  final Future<void> Function() run;
}
