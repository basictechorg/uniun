import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/gateway/session/relay_session.dart';
import 'package:uniun/gateway/subscriptions/sync_window.dart';

/// Context passed to every [SubscriptionProvider] call.
class SubscriptionContext {
  final Isar isar;
  final String? activePubkey;

  /// How far back the capped surfaces (feed / group / private-group
  /// messages) pull. Defaults to [kRecentSyncWindow]; the Gateway overrides it
  /// from the user's setting at boot.
  final Duration recentSyncWindow;

  const SubscriptionContext({
    required this.isar,
    this.activePubkey,
    this.recentSyncWindow = kRecentSyncWindow,
  });
}

/// Declarative description of one ongoing REQ subscription against a relay.
///
/// Each provider knows: its sub id, how to build its filter from current Isar
/// state, what local event ids to feed NIP-77 reconciliation, and (optionally)
/// a side-group REQ to issue right after the main sub opens.
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

  /// Event ids the active identity has tombstoned via [DeletedNoteModel].
  /// Providers whose filter can match a deletable note seed these into their
  /// [localIndex] so NIP-77 treats them as already-held and the relay stops
  /// re-offering them on every sync. (Reconciliation is download-only, so
  /// seeding ids the relay doesn't have under this filter is harmless.)
  Future<Iterable<String>> deletedEventIds(SubscriptionContext ctx) =>
      ctx.isar.deletedNoteModels.where().eventIdProperty().findAll();

  /// Companion REQs to fire right after the main subscription opens. Each is a
  /// plain (non-NIP-77) REQ — used for by-id metadata lookups (kind 40 / 9002)
  /// and for low-volume / crypto-critical events that must pull full history
  /// (kind 41 group metadata; the 9021/9022/9024/9025 MLS control plane).
  /// Returns an empty list for providers with no companion.
  Future<List<({String subId, Map<String, dynamic> filter})>> companionRequests(
    SubscriptionContext ctx,
  ) async =>
      const [];

  /// Called by the manager when this provider's sub should be (re)opened.
  /// Default: emits the standard CLOSE so the synchronizer can reopen.
  void close(RelaySession session) {
    session.unsubscribe(subId);
  }
}
