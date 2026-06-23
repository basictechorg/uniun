import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/encrypted_dm_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// NIP-17 inbound gift-wrap subscription, scoped to the active user's pubkey.
class DmsSubscription extends SubscriptionProvider {
  @override
  String get subId => 'dms';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    if (ctx.activePubkey == null) {
      return null;
    }
    return {
      'kinds': [1059],
      '#p': [ctx.activePubkey],
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final ids =
        await ctx.isar.encryptedDmModels.where().eventIdProperty().findAll();
    return {for (final id in ids) id: 0};
  }
}
