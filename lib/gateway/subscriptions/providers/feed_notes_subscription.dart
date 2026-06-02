import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// Subscribes to every Kind 1 (short text note) event on the relay so other
/// users' posts land in the local Isar and feed the Vishnu unified feed.
///
/// Without this, the relay would receive your published notes but never
/// deliver anyone else's back. The previous codebase only had
/// [FollowedNotesSubscription] which filters by `#e` for explicitly-followed
/// roots — not a general feed.
///
/// NIP-77 negentropy reconciliation is supported so we don't re-pull the
/// notes we already have on app open.
class FeedNotesSubscription extends SubscriptionProvider {
  @override
  String get subId => 'feed_notes';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    return {
      'kinds': [1],
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final ids = await ctx.isar.noteModels.where().eventIdProperty().findAll();
    return {for (final id in ids) id: 0};
  }
}
