import 'package:flutter/foundation.dart';
import 'package:nip77/nip77.dart';
import 'package:uniun/gateway/session/nostr_frame.dart';
import 'package:uniun/gateway/session/relay_session.dart';

/// Runs the NIP-77 → REQ fallback → live-tail dance for one subscription.
///
/// Centralizes the logic that used to live in [WebSocketService._syncOrFallback]
/// and was duplicated by every subscribe/resubscribe path.
///
/// Accepts an optional pre-connected [sharedClient] so callers (e.g.
/// [SubscriptionManager.openAll]) can open one [Nip77Client] per relay and
/// reuse it across multiple subscriptions — matching the original behavior
/// of [WebSocketService._performInitialSyncs].
class Nip77Synchronizer {
  Future<void> syncOrFallback({
    required RelaySession session,
    required String subId,
    required Map<String, dynamic> filter,
    required Future<Map<String, int>> Function() localIndex,
    Nip77Client? sharedClient,
    bool sharedClientConnected = false,
    bool wantsLiveTail = true,
    bool supportsNip77 = true,
  }) async {
    if (!session.read || !session.isConnected) return;

    // Providers that opt out of NIP-77 (low-volume metadata that must pull full
    // history regardless of age — e.g. kind-0 profiles) ignore any shared
    // client and fall straight through to a plain REQ. The open-ended filter
    // backfills history and live-tails future updates in one subscription, so
    // no separate `since=now` tail is needed.
    if (!supportsNip77) {
      session.sendRaw(NostrFrame.req(subId, filter));
      return;
    }

    Nip77Client? client = sharedClient;
    bool nip77Connected = sharedClientConnected;
    bool ownsClient = false;

    if (client == null) {
      client = Nip77Client(relayUrl: session.url);
      ownsClient = true;
      try {
        await client.connect();
        nip77Connected = true;
      } catch (e) {
        debugPrint('NIP-77: connect failed for ${session.url}: $e');
      }
    }

    bool useFallback = !nip77Connected;

    if (nip77Connected) {
      try {
        final myEvents = await localIndex();
        final syncResult = await client.syncEvents(
          myEvents: myEvents,
          filter: filter,
        );
        if (syncResult.needIds.isNotEmpty) {
          session.sendRaw(
            NostrFrame.req('${subId}_missing', {'ids': syncResult.needIds}),
          );
        }
      } catch (e) {
        debugPrint('NIP-77: sync failed for $subId: $e');
        useFallback = true;
      }
    }

    if (!session.isConnected) {
      if (ownsClient && nip77Connected) await client.disconnect();
      return;
    }

    if (useFallback) {
      session.sendRaw(NostrFrame.req(subId, filter));
    } else if (wantsLiveTail) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final liveFilter = Map<String, dynamic>.from(filter)..['since'] = nowSec;
      session.sendRaw(NostrFrame.req(subId, liveFilter));
    }

    if (ownsClient && nip77Connected) await client.disconnect();
  }
}
