import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/data/models/user_key_model.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/data/repositories/relay_repository_impl.dart';
import 'package:uniun/gateway/websocket_service.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';

/// Orchestrates all relay connections inside the Gateway isolate.
///
/// Responsibilities:
///  1. **Isar watcher on [EventQueueModel]** — when a new queue row appears,
///     notify all [WebSocketService]s so they can send immediately.
///  2. **Isar watcher on [RelayModel]** — when Isolate 1 adds or removes a
///     relay at runtime, sync the [_services] map accordingly.
///  3. **Isar watcher on [FollowedNoteModel]** — refresh `#e` [REQ] filters on
///     all [WebSocketService]s when the user follows/unfollows notes.
///  3b. **Isar watcher on [ChannelModel]** — re-run channel NIP-77 sync when
///      the user joins/leaves a channel (row added/removed).
///  4. **Dequeue timer** — every 5 minutes, delete queue entries that have
///     been sent by every active write relay AND are older than 30 minutes.
///
/// The Gateway isolate stays alive as long as [CentralRelayManager] holds
/// active timers and stream subscriptions.
class CentralRelayManager {
  final Isar _isar;

  /// One [WebSocketService] per relay URL.
  final Map<String, WebSocketService> _services = {};

  final Map<String, Timer> _tempRelayTimers = {};
  final Map<String, WebSocketService> _tempServices = {};
  int _lastHandledQueueId = 0;
  String? _activePubkey;

  Timer? _dequeueTimer;
  StreamSubscription<void>? _queueWatcher;
  StreamSubscription<void>? _relayWatcher;
  StreamSubscription<void>? _followedNotesWatcher;
  StreamSubscription<void>? _channelModelsWatcher;
  int _knownChannelCount = 0;

  CentralRelayManager({required Isar isar}) : _isar = isar;

  // ── Startup ────────────────────────────────────────────────────────────────

  Future<void> start() async {
    final activeKey = await _isar.userKeyModels
        .where()
        .findFirst();
    _activePubkey = activeKey?.pubkeyHex;

    // 1. Spin up one WebSocketService per persisted relay.
    var relays = await _isar.relayModels.where().findAll();

    // If no relays exist, save and use the default relay.
    if (relays.isEmpty) {
      final repo = RelayRepositoryImpl(isar: _isar);
      await repo.insertDefaultRelayIfEmpty();
      relays = await _isar.relayModels.where().findAll();
    }

    final allItems = await _isar.eventQueueModels.where().anyId().findAll();
    _lastHandledQueueId = allItems.isEmpty ? 0 : allItems.last.id;

    for (final relay in relays) {
      _addService(
        relay.url,
        read: relay.read,
        write: relay.write,
        fromTail: false,
        activePubkey: _activePubkey,
      );
    }

    // 2. Watch EventQueueModel so services send new items immediately.
    _queueWatcher = _isar.eventQueueModels.watchLazy().listen((_) async {
      await _runEventHandlerPass();
      for (final svc in _services.values) {
        svc.onNewQueueItem();
      }
      for (final svc in _tempServices.values) {
        svc.onNewQueueItem();
      }
    });

    // 3. Watch RelayModel for runtime add/remove from Isolate 1.
    _relayWatcher = _isar.relayModels.watchLazy().listen((_) {
      _syncRelayServices();
    });

    _followedNotesWatcher = _isar.followedNoteModels.watchLazy().listen((_) {
      for (final svc in _services.values) {
        svc.onFollowedNotesChanged();
      }
    });

    _knownChannelCount = await _loadChannelCount();
    _channelModelsWatcher = _isar.channelModels.watchLazy().listen((_) async {
      final currentCount = await _loadChannelCount();
      if (currentCount <= _knownChannelCount) {
        // Ignore metadata updates and non-additive changes.
        _knownChannelCount = currentCount;
        return;
      }
      _knownChannelCount = currentCount;
      for (final svc in _services.values) {
        svc.onChannelSubscriptionsChanged();
      }
    });

    // 4. Start dequeue cleanup timer.
    _dequeueTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _runDequeuePass();
    });
  }

  // ── Event Routing Handler ──────────────────────────────────────────────────

  Future<void> _runEventHandlerPass() async {
    final pending = await _isar.eventQueueModels
        .where()
        .idGreaterThan(_lastHandledQueueId)
        .findAll();

    if (pending.isEmpty) return;

    for (final event in pending) {
      if (event.id > _lastHandledQueueId) {
        _lastHandledQueueId = event.id;
      }
      final targets = await getTargetRelaysForEvent(event);
      if (targets != null) {
        for (final url in targets) {
          if (!_services.containsKey(url)) {
            _addTempService(url);
          }
        }
      }
    }
  }

  Future<List<String>?> getTargetRelaysForEvent(EventQueueModel event) async {
    final kind = event.kind;
    if (kind >= 40 && kind <= 44) {
      String? channelId;
      if (kind == 40) {
        channelId = event.eventId;
      } else {
        channelId = event.rootEventId;
      }

      if (channelId != null) {
        final channel = await _isar.channelModels
            .where()
            .channelIdEqualTo(channelId)
            .findFirst();
        if (channel != null && channel.relays.isNotEmpty) {
          return channel.relays;
        }
      }
      // If channel not found or has no relays, fallback to all main relays.
      return null;
    }

    if (kind == 1059) {
      // Direct message routing. Read #p from EventQueueModel's pTagRefs.
      if (event.pTagRefs.isNotEmpty) {
        final receiverPubkey = event.pTagRefs.first;
        final conversation = await _isar.dmConversationModels
            .where()
            .otherPubkeyEqualTo(receiverPubkey)
            .findFirst();

        if (conversation != null && conversation.relays.isNotEmpty) {
          return conversation.relays;
        }
      }
      return null;
    }

    // kind == 1 or others fall back to main relays.
    return null;
  }

  // ── Dequeue (timer callback) ───────────────────────────────────────────────

  Future<void> _runDequeuePass() async {
    final threshold = DateTime.now().subtract(const Duration(minutes: 30));

    // Best effort dequeue: drop any event older than 30 mins, since they now have
    // variable targets and maintain their own successful ACK skip state.
    final expired = await _isar.eventQueueModels
        .filter()
        .enqueuedAtLessThan(threshold)
        .findAll();

    if (expired.isEmpty) return;

    await _isar.writeTxn(() async {
      await _isar.eventQueueModels.deleteAll(expired.map((e) => e.id).toList());
    });
  }

  // ── Relay service management ───────────────────────────────────────────────

  /// Syncs [_services] with current [RelayModel] rows after a watcher fire.
  Future<void> _syncRelayServices() async {
    final current = await _isar.relayModels.where().findAll();
    final currentUrls = current.map((r) => r.url).toSet();
    final serviceUrls = Set<String>.from(_services.keys);

    // Add services for newly persisted relays.
    for (final relay in current) {
      if (!serviceUrls.contains(relay.url)) {
        // New relay starts from the current queue tail (only new events).
        _addService(
          relay.url,
          read: relay.read,
          write: relay.write,
          fromTail: true,
          activePubkey: _activePubkey,
        );
      }
    }

    // Remove services for deleted relays.
    for (final url in serviceUrls) {
      if (!currentUrls.contains(url)) {
        _services[url]?.disconnect();
        _services.remove(url);
      }
    }
  }

  Future<void> _updateRelayStatus(String url, RelayStatus status) async {
    await _isar.writeTxn(() async {
      final relay = await _isar.relayModels.where().urlEqualTo(url).findFirst();
      if (relay == null) return;
      relay.status = status;
      if (status == RelayStatus.connected) {
        relay.lastConnectedAt = DateTime.now();
      }
      await _isar.relayModels.put(relay);
    });
  }

  Future<void> _addService(
    String url, {
    required bool read,
    required bool write,
    required bool fromTail,
    String? activePubkey,
  }) async {
    int startId = 0;
    if (fromTail) {
      // New relay added at runtime — start from the current queue tail so it
      // only picks up events published after it was added.
      // anyId() returns items in ascending id order; the last item has the max id.
      final all = await _isar.eventQueueModels.where().anyId().findAll();
      startId = all.isEmpty ? 0 : all.last.id;
    }

    final svc = WebSocketService(
      url: url,
      read: read,
      write: write,
      isar: _isar,
      startFromQueueId: startId,
      activePubkey: activePubkey,
      onStatusChanged: (status) => _updateRelayStatus(url, status),
      resolveTargets: getTargetRelaysForEvent,
    );
    _services[url] = svc;
    svc.connect();
  }

  void _addTempService(String url) {
    if (_tempServices.containsKey(url)) {
      _extendTempServiceTimer(url);
      return;
    }

    final svc = WebSocketService(
      url: url,
      read: true,
      write: true,
      isar: _isar,
      startFromQueueId: _lastHandledQueueId,
      activePubkey: _activePubkey,
      resolveTargets: getTargetRelaysForEvent,
    );
    _tempServices[url] = svc;
    svc.connect();
    _extendTempServiceTimer(url);
  }

  void _extendTempServiceTimer(String url) {
    _tempRelayTimers[url]?.cancel();
    _tempRelayTimers[url] = Timer(const Duration(minutes: 5), () {
      _tempServices[url]?.disconnect();
      _tempServices.remove(url);
      _tempRelayTimers.remove(url);
    });
  }

  Future<int> _loadChannelCount() async {
    return _isar.channelModels.count();
  }

  // ── Shutdown ───────────────────────────────────────────────────────────────

  void stop() {
    _queueWatcher?.cancel();
    _relayWatcher?.cancel();
    _followedNotesWatcher?.cancel();
    _channelModelsWatcher?.cancel();
    _dequeueTimer?.cancel();
    for (final svc in _services.values) {
      svc.disconnect();
    }
    _services.clear();
    for (final svc in _tempServices.values) {
      svc.disconnect();
    }
    _tempServices.clear();
    for (final timer in _tempRelayTimers.values) {
      timer.cancel();
    }
    _tempRelayTimers.clear();
  }
}
