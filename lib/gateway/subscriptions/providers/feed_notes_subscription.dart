import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// Subscribes to Kind 1 notes scoped to the active user + everyone they follow.
///
/// The follow set comes from [FollowedUserModel] (kept in sync with the user's
/// Nostr Kind 3 event). When the follow set changes the orchestrator
/// resubscribes this provider via [IsarWatcherHub].
///
/// Empty follow list → filter narrows to just the active user's own notes, so
/// the relay stops streaming the public firehose at us.
class FeedNotesSubscription extends SubscriptionProvider {
  @override
  String get subId => 'feed_notes';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    if (ctx.activePubkey == null) return null;

    final followed =
        await ctx.isar.followedUserModels.where().pubkeyHexProperty().findAll();
    final authors = <String>{ctx.activePubkey!, ...followed}.toList();

    return {
      'kinds': [1],
      'authors': authors,
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final ids = await ctx.isar.noteModels.where().eventIdProperty().findAll();
    return {for (final id in ids) id: 0};
  }
}
