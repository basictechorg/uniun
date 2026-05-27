import 'package:flutter/foundation.dart';
import 'package:nip77/nip77.dart';
import 'package:uniun/gateway/session/nostr_frame.dart';
import 'package:uniun/gateway/session/relay_session.dart';
import 'package:uniun/gateway/subscriptions/nip77_synchronizer.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// Owns the lifecycle of all REQ subscriptions on one [RelaySession].
///
/// Doesn't know what any subscription means — providers describe themselves
/// (filter, local index, optional companion REQ). The manager is responsible
/// for ordering: connect → openAll, resubscribe(subId) on data change.
///
/// [openAll] opens one [Nip77Client] up-front and shares it across every
/// provider, matching the original [WebSocketService._performInitialSyncs]
/// behavior. [resubscribe] opens its own client per call.
class SubscriptionManager {
  final RelaySession session;
  final List<SubscriptionProvider> providers;
  final Nip77Synchronizer synchronizer;
  final SubscriptionContext context;

  SubscriptionManager({
    required this.session,
    required this.providers,
    required this.synchronizer,
    required this.context,
  });

  /// Open all providers' subscriptions. Called after a session connects.
  Future<void> openAll() async {
    Nip77Client? shared;
    bool sharedConnected = false;
    final anyNeedsNip77 = providers.any((p) => p.supportsNip77);

    if (anyNeedsNip77) {
      shared = Nip77Client(relayUrl: session.url);
      try {
        await shared.connect();
        sharedConnected = true;
      } catch (e) {
        debugPrint('NIP-77: shared client connect failed for ${session.url}: $e');
      }
    }

    try {
      for (final p in providers) {
        await _open(
          p,
          sharedClient: shared,
          sharedClientConnected: sharedConnected,
        );
      }
    } finally {
      if (sharedConnected) await shared!.disconnect();
    }
  }

  /// Re-issue a single provider's subscription. Called when the underlying
  /// Isar data it depends on changes.
  Future<void> resubscribe(String subId) async {
    for (final p in providers) {
      if (p.subId != subId) continue;
      p.close(session);
      await _open(p);
      return;
    }
  }

  Future<void> _open(
    SubscriptionProvider p, {
    Nip77Client? sharedClient,
    bool sharedClientConnected = false,
  }) async {
    final filter = await p.buildFilter(context);
    if (filter == null) return;

    await synchronizer.syncOrFallback(
      session: session,
      subId: p.subId,
      filter: filter,
      localIndex: () => p.localIndex(context),
      sharedClient: sharedClient,
      sharedClientConnected: sharedClientConnected,
      wantsLiveTail: p.wantsLiveTail,
      supportsNip77: p.supportsNip77,
    );

    final companion = await p.companionRequest(context);
    if (companion != null && session.isConnected) {
      session.sendRaw(NostrFrame.req(companion.subId, companion.filter));
    }
  }
}
