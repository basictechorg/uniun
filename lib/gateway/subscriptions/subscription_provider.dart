import 'package:isar_community/isar.dart';
import 'package:uniun/gateway/session/relay_session.dart';

/// Context passed to every [SubscriptionProvider] call.
class SubscriptionContext {
  final Isar isar;
  final String? activePubkey;
  const SubscriptionContext({required this.isar, this.activePubkey});
}

/// Declarative description of one ongoing REQ subscription against a relay.
///
/// Each provider knows: its sub id, how to build its filter from current Isar
/// state, what local event ids to feed NIP-77 reconciliation, and (optionally)
/// a side-channel REQ to issue right after the main sub opens.
abstract class SubscriptionProvider {
  /// REQ subscription id. Used both to open and close the sub.
  String get subId;

  /// If false, the synchronizer skips NIP-77 entirely and only uses REQ.
  bool get supportsNip77 => true;

  /// If true, the synchronizer also issues `since=now` after a successful
  /// NIP-77 sync, so the relay live-tails new matching events.
  bool get wantsLiveTail => true;

  /// Build the REQ filter from current Isar state. Return null to skip — e.g.
  /// when there are no followed notes to subscribe to yet.
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx);

  /// Map of `{eventId: timestamp}` of events we already have locally that
  /// match this filter. Fed to NIP-77's negentropy reconciliation.
  Future<Map<String, int>> localIndex(SubscriptionContext ctx);

  /// Optional companion REQ to fire right after the main subscription opens.
  /// Returns the (subId, filter) pair, or null for none.
  /// Used by channel and private-channel providers to fetch kind-40 / kind-9002
  /// metadata by id, which can't be expressed as an `#e` filter.
  Future<({String subId, Map<String, dynamic> filter})?> companionRequest(
    SubscriptionContext ctx,
  ) async =>
      null;

  /// Called by the manager when this provider's sub should be (re)opened.
  /// Default: emits the standard CLOSE so the synchronizer can reopen.
  void close(RelaySession session) {
    session.unsubscribe(subId);
  }
}
