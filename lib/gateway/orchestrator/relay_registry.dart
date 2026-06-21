import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/gateway/inbound/inbound_bus.dart';
import 'package:uniun/gateway/orchestrator/relay_status_reporter.dart';
import 'package:uniun/gateway/outbound/event_router.dart';
import 'package:uniun/gateway/outbound/outbound_pump.dart';
import 'package:uniun/gateway/session/nostr_frame.dart';
import 'package:uniun/gateway/session/relay_session.dart';
import 'package:uniun/gateway/subscriptions/nip77_synchronizer.dart';
import 'package:uniun/gateway/subscriptions/subscription_manager.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'package:uniun/gateway/subscriptions/sync_window.dart';
import 'package:uniun/gateway/transport/relay_connection.dart';

/// Bundles everything that hangs off a single [RelaySession] so the lifecycle
/// is one unit.
class _RegistryEntry {
  final RelaySession session;
  final OutboundPump pump;
  final SubscriptionManager subscriptions;
  final StreamSubscription<InboundEvent> inboundSub;
  final StreamSubscription<ConnectionState> stateSub;
  _RegistryEntry({
    required this.session,
    required this.pump,
    required this.subscriptions,
    required this.inboundSub,
    required this.stateSub,
  });
}

/// Owns every active [RelaySession] keyed by URL.
///
/// Persistent sessions come from [RelayModel]; ephemeral sessions are opened
/// on-demand by [TempSessionCoordinator] when an event needs a relay we don't
/// otherwise connect to. Both are stored in the same map — the only difference
/// is [RelaySession.lifetime] and who controls their TTL.
class RelayRegistry {
  final Isar _isar;
  final EventRouter _router;
  final InboundBus _inboundBus;
  final Nip77Synchronizer _synchronizer;
  final RelayStatusReporter _statusReporter;
  final List<SubscriptionProvider> Function() _providerFactory;
  final String? _activePubkey;
  final Duration _recentSyncWindow;

  final Map<String, _RegistryEntry> _entries = {};

  RelayRegistry({
    required Isar isar,
    required EventRouter router,
    required InboundBus inboundBus,
    required Nip77Synchronizer synchronizer,
    required RelayStatusReporter statusReporter,
    required List<SubscriptionProvider> Function() providerFactory,
    String? activePubkey,
    Duration recentSyncWindow = kRecentSyncWindow,
  })  : _isar = isar,
        _router = router,
        _inboundBus = inboundBus,
        _synchronizer = synchronizer,
        _statusReporter = statusReporter,
        _providerFactory = providerFactory,
        _activePubkey = activePubkey,
        _recentSyncWindow = recentSyncWindow;

  RelaySession? get(String url) => _entries[url]?.session;
  Iterable<RelaySession> get all =>
      _entries.values.map((e) => e.session);
  Iterable<RelaySession> get persistent => _entries.values
      .where((e) => e.session.lifetime == SessionLifetime.persistent)
      .map((e) => e.session);

  Future<void> openPersistent(
    String url, {
    required bool read,
    required bool write,
    required int startFromQueueId,
  }) async {
    if (_entries.containsKey(url)) return;
    _create(
      url: url,
      read: read,
      write: write,
      lifetime: SessionLifetime.persistent,
      startFromQueueId: startFromQueueId,
    );
  }

  Future<void> openEphemeral(
    String url, {
    required int startFromQueueId,
  }) async {
    if (_entries.containsKey(url)) return;
    _create(
      url: url,
      read: true,
      write: true,
      lifetime: SessionLifetime.ephemeral,
      startFromQueueId: startFromQueueId,
    );
  }

  Future<void> close(String url) async {
    final entry = _entries.remove(url);
    if (entry == null) return;
    await entry.inboundSub.cancel();
    await entry.stateSub.cancel();
    await entry.pump.dispose();
    await entry.session.disconnect();
  }

  /// Wakes every pump (called when the queue changes).
  void notifyQueueChanged() {
    for (final e in _entries.values) {
      e.pump.onTick();
    }
  }

  /// Resubscribes [subId] across every session (persistent and ephemeral).
  Future<void> resubscribeAll(String subId) async {
    for (final e in _entries.values) {
      await e.subscriptions.resubscribe(subId);
    }
  }

  Future<void> disposeAll() async {
    final urls = List<String>.from(_entries.keys);
    for (final url in urls) {
      await close(url);
    }
  }

  void _create({
    required String url,
    required bool read,
    required bool write,
    required SessionLifetime lifetime,
    required int startFromQueueId,
  }) {
    final connection = RelayConnection(url: url);
    final session = RelaySession(
      connection: connection,
      read: read,
      write: write,
      lifetime: lifetime,
    );

    final pump = OutboundPump(
      isar: _isar,
      session: session,
      startFromQueueId: startFromQueueId,
      shouldSendToThisSession: (q) => _shouldSendToThisSession(session, q),
    );

    final subscriptions = SubscriptionManager(
      session: session,
      providers: _providerFactory(),
      synchronizer: _synchronizer,
      context: SubscriptionContext(
        isar: _isar,
        activePubkey: _activePubkey,
        recentSyncWindow: _recentSyncWindow,
      ),
    );

    final inboundSub = _inboundBus.attach(session);
    final stateSub = session.states.listen((state) {
      unawaited(_statusReporter.report(url, state));
      if (state == ConnectionState.connected) {
        unawaited(subscriptions.openAll());
        pump.onTick();
      }
    });

    _entries[url] = _RegistryEntry(
      session: session,
      pump: pump,
      subscriptions: subscriptions,
      inboundSub: inboundSub,
      stateSub: stateSub,
    );

    session.connect();
  }

  Future<bool> _shouldSendToThisSession(
    RelaySession session,
    EventQueueModel item,
  ) async {
    if (!session.write) return false;
    final targets = await _router.resolveTargets(item);
    // null means "default fanout" — every write session sends, persistent
    // and ephemeral alike. This matches the original WebSocketService gate
    // which only filtered when targets was non-null.
    if (targets == null) return true;
    return targets.contains(session.url);
  }
}
