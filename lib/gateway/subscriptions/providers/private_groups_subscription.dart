import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/encrypted_message_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'package:uniun/gateway/subscriptions/sync_window.dart';

/// Marmot/OpenMLS private groups.
///
/// Main filter (NIP-77 synced) covers kind 9023 application messages only,
/// capped to the recent-sync window. The MLS control plane — 9024 Welcome /
/// 9025 Commit (epoch key rotation), plus 9021 join key-package and 9022 — and
/// kind 9002 metadata ride uncapped companion REQs: capping them would drop the
/// commit chain and break decryption for the whole group.
class PrivateGroupsSubscription extends SubscriptionProvider {
  @override
  String get subId => 'private_groups';

  String get _metaSubId => '${subId}_meta';
  String get _mlsSubId => '${subId}_mls';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    final privates = await ctx.isar.privateGroupModels.where().findAll();
    if (privates.isEmpty) return null;
    return {
      'kinds': [kPrivateGroupKind],
      '#h': privates.map((c) => c.groupId).toList(),
      'since': recentSyncSinceEpochSeconds(ctx.recentSyncWindow),
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final out = <String, int>{};
    final encIds = await ctx.isar.encryptedMessageModels
        .filter()
        .kindEqualTo(kPrivateGroupKind)
        .eventIdProperty()
        .findAll();
    for (final id in encIds) {
      out[id] = 0;
    }
    final decIds = await ctx.isar.noteModels
        .filter()
        .privateGroupIdIsNotNull()
        .eventIdProperty()
        .findAll();
    for (final id in decIds) {
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
    final privates = await ctx.isar.privateGroupModels.where().findAll();
    if (privates.isEmpty) return const [];
    final groupIds = privates.map((c) => c.groupId).toList();
    return [
      (subId: _metaSubId, filter: {'kinds': [9002], 'ids': groupIds}),
      (
        subId: _mlsSubId,
        filter: {'kinds': [9021, 9022, 9024, 9025], '#h': groupIds},
      ),
    ];
  }

  @override
  void close(session) {
    session.unsubscribe(subId);
    session.unsubscribe(_metaSubId);
    session.unsubscribe(_mlsSubId);
  }
}
