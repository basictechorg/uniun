import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'package:uniun/gateway/subscriptions/sync_window.dart';

/// NIP-28 group metadata + messages for every locally joined group.
///
/// Main filter (NIP-77 synced) covers kind 42 messages only, capped to the
/// recent-sync window. Group creation (kind 40, by `ids`) and metadata edits
/// (kind 41, by `#e`) are low-volume and must never be capped — a group
/// renamed long ago must still resolve — so they ride uncapped companion REQs.
class GroupsSubscription extends SubscriptionProvider {
  @override
  String get subId => 'groups';

  String get _infoSubId => '${subId}_info';
  String get _metaSubId => '${subId}_meta';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    final groups = await ctx.isar.groupModels.where().findAll();
    if (groups.isEmpty) return null;
    return {
      'kinds': [kGroupMessageKind],
      '#e': groups.map((c) => c.groupId).toList(),
      'since': recentSyncSinceEpochSeconds(ctx.recentSyncWindow),
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final out = <String, int>{};
    final ids = await ctx.isar.noteModels
        .filter()
        .kindEqualTo(kGroupMessageKind)
        .eventIdProperty()
        .findAll();
    for (final id in ids) {
      out[id] = 0;
    }
    for (final id in await deletedEventIds(ctx)) {
      out[id] = 0;
    }
    return out;
  }

  @override
  Future<List<({String subId, Map<String, dynamic> filter})>> companionRequests(
    SubscriptionContext ctx,
  ) async {
    final groups = await ctx.isar.groupModels.where().findAll();
    if (groups.isEmpty) return const [];
    final groupIds = groups.map((c) => c.groupId).toList();
    return [
      (subId: _infoSubId, filter: {'kinds': [40], 'ids': groupIds}),
      (subId: _metaSubId, filter: {'kinds': [41], '#e': groupIds}),
    ];
  }

  @override
  void close(session) {
    session.unsubscribe(subId);
    session.unsubscribe(_infoSubId);
    session.unsubscribe(_metaSubId);
  }
}
