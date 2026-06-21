import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'package:uniun/gateway/subscriptions/sync_window.dart';

/// NIP-28 channel metadata + messages for every locally joined channel.
///
/// Main filter (NIP-77 synced) covers kind 42 messages only, capped to the
/// recent-sync window. Channel creation (kind 40, by `ids`) and metadata edits
/// (kind 41, by `#e`) are low-volume and must never be capped — a channel
/// renamed long ago must still resolve — so they ride uncapped companion REQs.
class ChannelsSubscription extends SubscriptionProvider {
  @override
  String get subId => 'channels';

  String get _infoSubId => '${subId}_info';
  String get _metaSubId => '${subId}_meta';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    final channels = await ctx.isar.channelModels.where().findAll();
    if (channels.isEmpty) return null;
    return {
      'kinds': [kChannelMessageKind],
      '#e': channels.map((c) => c.channelId).toList(),
      'since': recentSyncSinceEpochSeconds(ctx.recentSyncWindow),
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final out = <String, int>{};
    final ids = await ctx.isar.noteModels
        .filter()
        .kindEqualTo(kChannelMessageKind)
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
    final channels = await ctx.isar.channelModels.where().findAll();
    if (channels.isEmpty) return const [];
    final channelIds = channels.map((c) => c.channelId).toList();
    return [
      (subId: _infoSubId, filter: {'kinds': [40], 'ids': channelIds}),
      (subId: _metaSubId, filter: {'kinds': [41], '#e': channelIds}),
    ];
  }

  @override
  void close(session) {
    session.unsubscribe(subId);
    session.unsubscribe(_infoSubId);
    session.unsubscribe(_metaSubId);
  }
}
