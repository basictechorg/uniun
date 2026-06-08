import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/blocked_user_model.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
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

  /// In-memory set of blocked author pubkeys. Kept in sync with the
  /// `BlockedUser` Isar collection via [init]. Every inbound event whose
  /// `pubkey` is in this set is dropped before any handler sees it.
  final Set<String> _blockedPubkeys = {};
  StreamSubscription<void>? _blockedSub;

  /// In-memory set of locally-deleted note event IDs. Kept in sync with the
  /// `DeletedNote` Isar collection via [init]. Every inbound event whose `id`
  /// is in this set is dropped before any handler sees it, so a note the user
  /// deleted never resyncs.
  final Set<String> _deletedEventIds = {};
  StreamSubscription<void>? _deletedSub;

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

  /// Loads the blocked-pubkey set and keeps it fresh. Must be awaited before
  /// the bus is attached to any session so the filter is active from the first
  /// inbound event.
  Future<void> init() async {
    await _reloadBlocked();
    await _reloadDeleted();
    _blockedSub = _isar.blockedUserModels.watchLazy().listen((_) async {
      await _reloadBlocked();
    });
    _deletedSub = _isar.deletedNoteModels.watchLazy().listen((_) async {
      await _reloadDeleted();
    });
  }

  Future<void> _reloadBlocked() async {
    final rows = await _isar.blockedUserModels.where().findAll();
    _blockedPubkeys
      ..clear()
      ..addAll(rows.map((r) => r.pubkeyHex));
  }

  Future<void> _reloadDeleted() async {
    final rows = await _isar.deletedNoteModels.where().findAll();
    _deletedEventIds
      ..clear()
      ..addAll(rows.map((r) => r.eventId));
  }

  /// Subscribe this bus to one session's [RelaySession.events] stream.
  /// Returns a disposable so the orchestrator can cancel per-session.
  StreamSubscription<InboundEvent> attach(RelaySession session) {
    return session.events.listen(_onEvent);
  }

  Future<void> _onEvent(InboundEvent msg) async {
    final event = msg.event;
    // Drop everything authored by a blocked user before any tracking or
    // persistence. Note: Kind-1059 DM gift wraps carry an ephemeral wrapper
    // pubkey, so this does not block DMs by their real author — acceptable,
    // since blocking targets feed/note content.
    final pubkey = event['pubkey'] as String?;
    if (pubkey != null && _blockedPubkeys.contains(pubkey)) {
      debugPrint('GATEWAY: event from blocked $pubkey — dropped');
      return;
    }
    // Drop anything the user has locally deleted so it never resyncs.
    final id = event['id'] as String?;
    if (id != null && _deletedEventIds.contains(id)) {
      debugPrint('GATEWAY: event $id is tombstoned — dropped');
      return;
    }
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
    await _blockedSub?.cancel();
    await _deletedSub?.cancel();
  }
}
