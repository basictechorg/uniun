import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// NIP-28 channel metadata + messages for every locally joined channel.
///
/// The main filter covers kinds 41 (meta updates) and 42 (messages) via
/// `#e` against the channel ids. A companion REQ (kind 40 by `ids`) is needed
/// because the channel creation event's id IS the channel id — no `#e` tag
/// would match it.
class ChannelsSubscription extends SubscriptionProvider {
  @override
  String get subId => 'channels';

  String get _infoSubId => '${subId}_info';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    final channels = await ctx.isar.channelModels.where().findAll();
    if (channels.isEmpty) return null;
    return {
      'kinds': [41, 42],
      '#e': channels.map((c) => c.channelId).toList(),
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final out = <String, int>{};
    final channels = await ctx.isar.channelModels.where().findAll();
    for (final ch in channels) {
      if (ch.lastMetaEvent != null) out[ch.lastMetaEvent!] = 0;
    }
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
  Future<({String subId, Map<String, dynamic> filter})?> companionRequest(
    SubscriptionContext ctx,
  ) async {
    final channels = await ctx.isar.channelModels.where().findAll();
    if (channels.isEmpty) return null;
    return (
      subId: _infoSubId,
      filter: {
        'kinds': [40],
        'ids': channels.map((c) => c.channelId).toList(),
      },
    );
  }

  @override
  void close(session) {
    session.unsubscribe(subId);
    session.unsubscribe(_infoSubId);
  }
}
