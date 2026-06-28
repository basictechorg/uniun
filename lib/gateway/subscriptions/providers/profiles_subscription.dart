import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// Kind 0 (profile metadata) for every pubkey we've seen but don't yet have
/// a [ProfileModel] for. Sub is re-opened whenever [MissingProfilePubkeyModel]
/// changes.
///
/// Profiles are low-volume metadata that must resolve regardless of age — a
/// profile published long ago must still arrive. Like the kind 40/41 group
/// metadata in [GroupsSubscription], it therefore opts out of NIP-77 and
/// rides a plain uncapped REQ: ProfileModel carries no source event id, so we
/// can't seed negentropy with what we hold, and a `since=now` live-tail would
/// silently miss every historical profile. The open-ended REQ backfills history
/// and live-tails future updates in one subscription.
class ProfilesSubscription extends SubscriptionProvider {
  @override
  String get subId => 'profiles';

  @override
  bool get supportsNip77 => false;

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
    // Unused — NIP-77 is disabled for this provider (see class doc).
    return const {};
  }
}
