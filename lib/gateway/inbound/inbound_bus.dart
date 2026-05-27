import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/missing_profile_tracker.dart';
import 'package:uniun/gateway/session/nostr_frame.dart';
import 'package:uniun/gateway/session/relay_session.dart';

/// Dispatches inbound [InboundEvent]s from a [RelaySession] to the first
/// [KindHandler] whose [KindHandler.kinds] contains the event's `kind`.
///
/// Also runs the [MissingProfileTracker] middleware on every event regardless
/// of whether a kind handler matches.
class InboundBus {
  final Isar _isar;
  final List<KindHandler> _handlers;
  final MissingProfileTracker _missingProfileTracker;

  final Map<int, KindHandler> _byKind = {};
  StreamSubscription<InboundEvent>? _sub;

  InboundBus({
    required Isar isar,
    required List<KindHandler> handlers,
    required MissingProfileTracker missingProfileTracker,
  })  : _isar = isar,
        _handlers = handlers,
        _missingProfileTracker = missingProfileTracker {
    for (final h in _handlers) {
      for (final k in h.kinds) {
        _byKind[k] = h;
      }
    }
  }

  /// Subscribe this bus to one session's [RelaySession.events] stream.
  /// Returns a disposable so the orchestrator can cancel per-session.
  StreamSubscription<InboundEvent> attach(RelaySession session) {
    return session.events.listen(_onEvent);
  }

  Future<void> _onEvent(InboundEvent msg) async {
    final event = msg.event;
    unawaited(_missingProfileTracker.track(event));
    final kind = event['kind'] as int?;
    debugPrint('GATEWAY: inbound EVENT sub=${msg.subId} kind=$kind id=${event['id']}');
    if (kind == null) return;
    final handler = _byKind[kind];
    if (handler == null) {
      debugPrint('GATEWAY: no handler for kind=$kind — dropped');
      return;
    }
    await handler.handle(event, _isar);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
