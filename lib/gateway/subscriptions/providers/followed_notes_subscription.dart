import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';

/// Kind 1 notes that reference any followed root via an `#e` filter.
class FollowedNotesSubscription extends SubscriptionProvider {
  @override
  String get subId => 'followed_note_refs';

  @override
  Future<Map<String, dynamic>?> buildFilter(SubscriptionContext ctx) async {
    final followed = await ctx.isar.followedNoteModels.where().findAll();
    if (followed.isEmpty) return null;
    return {
      'kinds': [1],
      '#e': followed.map((f) => f.eventId).toList(),
    };
  }

  @override
  Future<Map<String, int>> localIndex(SubscriptionContext ctx) async {
    final ids = await ctx.isar.noteModels.where().eventIdProperty().findAll();
    return {
      for (final id in ids) id: 0,
      for (final id in await deletedEventIds(ctx)) id: 0,
    };
  }
}
