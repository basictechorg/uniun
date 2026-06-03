import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/data/repositories/relay_repository_impl.dart';
import 'package:uniun/gateway/inbound/handlers/kind0_profile_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind1059_dm_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind3_contact_list_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind1_note_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind40_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind41_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind42_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind9002_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind9021_25_handler.dart';
import 'package:uniun/gateway/inbound/inbound_bus.dart';
import 'package:uniun/gateway/inbound/missing_profile_tracker.dart';
import 'package:uniun/gateway/orchestrator/relay_registry.dart';
import 'package:uniun/gateway/orchestrator/relay_status_reporter.dart';
import 'package:uniun/gateway/outbound/event_router.dart';
import 'package:uniun/gateway/outbound/routing/channel_routing_strategy.dart';
import 'package:uniun/gateway/outbound/routing/dm_routing_strategy.dart';
import 'package:uniun/gateway/outbound/routing/private_channel_routing_strategy.dart';
import 'package:uniun/gateway/outbound/temp_session_coordinator.dart';
import 'package:uniun/gateway/subscriptions/nip77_synchronizer.dart';
import 'package:uniun/gateway/subscriptions/providers/channels_subscription.dart';
import 'package:uniun/gateway/subscriptions/providers/dms_subscription.dart';
import 'package:uniun/gateway/subscriptions/providers/feed_notes_subscription.dart';
import 'package:uniun/gateway/subscriptions/providers/followed_notes_subscription.dart';
import 'package:uniun/gateway/subscriptions/providers/private_channels_subscription.dart';
import 'package:uniun/gateway/subscriptions/providers/profiles_subscription.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'package:uniun/gateway/watchers/isar_watcher_hub.dart';

/// Top-level wiring for the Gateway isolate.
///
/// Replaces [CentralRelayManager]. Responsibilities:
///  - Open a persistent [RelaySession] per [RelayModel] at startup.
///  - Run an Isar watcher hub that pokes the right pipeline on each change.
///  - Decide when to open ephemeral sessions for events targeted at non-main
///    relays, and let [TempSessionCoordinator] expire them.
///  - Run the dequeue timer (drops queue rows older than 30 minutes).
///
/// The orchestrator owns no event-handling or routing logic — those live in
/// pluggable handlers and strategies. Adding a new Nostr kind or subscription
/// does not require editing this file.
class GatewayOrchestrator {
  final Isar _isar;
  final String? _activePubkey;

  late final EventRouter _router;
  late final RelayRegistry _registry;
  late final TempSessionCoordinator _tempCoordinator;
  late final IsarWatcherHub _watcherHub;

  int _lastHandledQueueId = 0;
  Timer? _dequeueTimer;

  GatewayOrchestrator({required Isar isar, String? activePubkey})
      : _isar = isar,
        _activePubkey = activePubkey;

  Future<void> start() async {
    var relays = await _isar.relayModels.where().findAll();
    if (relays.isEmpty) {
      await RelayRepositoryImpl(isar: _isar).insertDefaultRelayIfEmpty();
      relays = await _isar.relayModels.where().findAll();
    }

    final allQueue = await _isar.eventQueueModels.where().anyId().findAll();
    _lastHandledQueueId = allQueue.isEmpty ? 0 : allQueue.last.id;

    _router = EventRouter(
      isar: _isar,
      strategies: [
        ChannelRoutingStrategy(),
        DmRoutingStrategy(),
        PrivateChannelRoutingStrategy(),
      ],
    );

    final inboundBus = InboundBus(
      isar: _isar,
      missingProfileTracker: MissingProfileTracker(_isar),
      handlers: [
        Kind1NoteHandler(),
        Kind0ProfileHandler(),
        Kind3ContactListHandler(activePubkey: _activePubkey),
        Kind40Handler(),
        Kind41Handler(),
        Kind42Handler(),
        Kind1059DmHandler(),
        Kind9002Handler(),
        Kind9021To9025Handler(activePubkey: _activePubkey),
      ],
    );

    _registry = RelayRegistry(
      isar: _isar,
      router: _router,
      inboundBus: inboundBus,
      synchronizer: Nip77Synchronizer(),
      statusReporter: RelayStatusReporter(_isar),
      providerFactory: _subscriptionProviders,
      activePubkey: _activePubkey,
    );

    _tempCoordinator = TempSessionCoordinator(
      openIfMissing: (url) {
        if (_registry.get(url) != null) return;
        unawaited(_registry.openEphemeral(
          url,
          startFromQueueId: _lastHandledQueueId,
        ));
      },
      closeNow: (url) => unawaited(_registry.close(url)),
    );

    for (final relay in relays) {
      await _registry.openPersistent(
        relay.url,
        read: relay.read,
        write: relay.write,
        startFromQueueId: 0,
      );
    }

    _watcherHub = IsarWatcherHub(
      isar: _isar,
      handlers: WatcherHandlers(
        onQueueChanged: _onQueueChanged,
        onRelayModelsChanged: _syncRelayServices,
        onFollowedNotesChanged: () =>
            _registry.resubscribeAll('followed_note_refs'),
        onFollowedUsersChanged: () => _registry.resubscribeAll('feed_notes'),
        onMissingProfilesChanged: () => _registry.resubscribeAll('profiles'),
        onChannelsChangedAdditive: () => _registry.resubscribeAll('channels'),
        onPrivateChannelsChangedAdditive: () =>
            _registry.resubscribeAll('private_channels'),
      ),
    );
    await _watcherHub.start();

    _dequeueTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_runDequeuePass()),
    );
  }

  Future<void> stop() async {
    _dequeueTimer?.cancel();
    await _watcherHub.dispose();
    _tempCoordinator.disposeAll();
    await _registry.disposeAll();
  }

  List<SubscriptionProvider> _subscriptionProviders() => [
        DmsSubscription(),
        ProfilesSubscription(),
        FollowedNotesSubscription(),
        FeedNotesSubscription(),
        ChannelsSubscription(),
        PrivateChannelsSubscription(),
      ];

  Future<void> _onQueueChanged() async {
    // 1. Walk new queue rows, spin up temp sessions for any non-main targets.
    final pending = await _isar.eventQueueModels
        .where()
        .idGreaterThan(_lastHandledQueueId)
        .findAll();

    for (final event in pending) {
      if (event.id > _lastHandledQueueId) _lastHandledQueueId = event.id;
      final targets = await _router.resolveTargets(event);
      if (targets == null) continue;
      for (final url in targets) {
        if (_registry.persistent.any((s) => s.url == url)) continue;
        _tempCoordinator.touch(url);
      }
    }

    // 2. Wake every pump (persistent + ephemeral) to drain the queue.
    _registry.notifyQueueChanged();
  }

  Future<void> _syncRelayServices() async {
    final current = await _isar.relayModels.where().findAll();
    final currentUrls = current.map((r) => r.url).toSet();
    final activeUrls = _registry.persistent.map((s) => s.url).toSet();

    // New persistent relay → starts from the current queue tail so it only
    // picks up events published after it was added.
    final all = await _isar.eventQueueModels.where().anyId().findAll();
    final tail = all.isEmpty ? 0 : all.last.id;

    for (final relay in current) {
      if (!activeUrls.contains(relay.url)) {
        await _registry.openPersistent(
          relay.url,
          read: relay.read,
          write: relay.write,
          startFromQueueId: tail,
        );
      }
    }
    for (final url in activeUrls) {
      if (!currentUrls.contains(url)) {
        await _registry.close(url);
      }
    }
  }

  Future<void> _runDequeuePass() async {
    final threshold = DateTime.now().subtract(const Duration(minutes: 30));
    await _isar.writeTxn(() async {
      await _isar.eventQueueModels
          .filter()
          .enqueuedAtLessThan(threshold)
          .deleteAll();
    });
  }
}
