import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// Kind 0 (profile metadata) for every pubkey we've seen but don't yet have
/// a [ProfileModel] for. Sub is re-opened whenever [MissingProfilePubkeyModel]
/// changes.
class ProfilesSubscription extends SubscriptionProvider {
  @override
  String get subId => 'profiles';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    final missing = await ctx.isar.missingProfilePubkeyModels.where().findAll();
    if (missing.isEmpty) return null;
    return {
      'kinds': [0],
      'authors': missing.map((m) => m.pubkey).toList(),
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    // ProfileModel doesn't carry the source event id, so we can't seed NIP-77
    // with what we have. Matches the original behavior in the kind-0 branch
    // of _getLocalEventIdsForFilter.
    return const {};
  }
}
