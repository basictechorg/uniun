import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/encrypted_message_model.dart';
import 'package:uniun/data/models/private_channel_join_request_model.dart';
import 'package:uniun/data/models/private_channel_message_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// Marmot private channel envelopes (9021-9025) + metadata (9002).
///
/// 9021-9025 are filtered by `#h` against the group ids. Kind 9002 (metadata)
/// uses an `ids` lookup since group id == metadata event id in this protocol.
class PrivateChannelsSubscription extends SubscriptionProvider {
  @override
  String get subId => 'private_channels';

  String get _metaSubId => '${subId}_meta';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    final privates = await ctx.isar.privateChannelModels.where().findAll();
    if (privates.isEmpty) return null;
    return {
      'kinds': [9021, 9022, 9023, 9024, 9025],
      '#h': privates.map((c) => c.groupId).toList(),
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final out = <String, int>{};
    final joinIds = await ctx.isar.privateChannelJoinRequestModels
        .where()
        .eventIdProperty()
        .findAll();
    for (final id in joinIds) {
      out[id] = 0;
    }
    final encIds = await ctx.isar.encryptedMessageModels
        .where()
        .eventIdProperty()
        .findAll();
    for (final id in encIds) {
      out[id] = 0;
    }
    final decIds = await ctx.isar.privateChannelMessageModels
        .where()
        .eventIdProperty()
        .findAll();
    for (final id in decIds) {
      out[id] = 0;
    }
    return out;
  }

  @override
  Future<({String subId, Map<String, dynamic> filter})?> companionRequest(
    SubscriptionContext ctx,
  ) async {
    final privates = await ctx.isar.privateChannelModels.where().findAll();
    if (privates.isEmpty) return null;
    return (
      subId: _metaSubId,
      filter: {
        'kinds': [9002],
        'ids': privates.map((c) => c.groupId).toList(),
      },
    );
  }

  @override
  void close(session) {
    session.unsubscribe(subId);
    session.unsubscribe(_metaSubId);
  }
}
