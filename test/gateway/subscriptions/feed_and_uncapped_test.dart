import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/gateway/subscriptions/providers/dms_subscription.dart';
import 'package:uniun/gateway/subscriptions/providers/feed_notes_subscription.dart';
import 'package:uniun/gateway/subscriptions/providers/followed_notes_subscription.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'isar_test_harness.dart';

void main() {
  late Isar isar;
  setUp(() async => isar = await openTestIsar());
  tearDown(() async => isar.close(deleteFromDisk: true));

  test('feed caps followed-author notes to last 7 days', () async {
    await isar.writeTxn(() => isar.followedUserModels.put(followedUserSeed('pkFollowed')));
    final filter = await FeedNotesSubscription()
        .buildFilter(SubscriptionContext(isar: isar, activePubkey: 'pkMe'));

    expect(filter!['kinds'], [1]);
    expect((filter['authors'] as List).toSet(), {'pkMe', 'pkFollowed'});
    final expectedSince =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/
            1000;
    expect(((filter['since'] as int) - expectedSince).abs(), lessThan(5));
  });

  test('followed notes pull all history (no since)', () async {
    await isar.writeTxn(() => isar.followedNoteModels.put(followedNoteSeed('note1')));
    final filter =
        await FollowedNotesSubscription().buildFilter(SubscriptionContext(isar: isar));

    expect(filter!['kinds'], [1]);
    expect(filter['#e'], ['note1']);
    expect(filter.containsKey('since'), isFalse);
  });

  test('DMs pull all history (no since)', () async {
    final filter = await DmsSubscription()
        .buildFilter(SubscriptionContext(isar: isar, activePubkey: 'pkMe'));

    expect(filter!['kinds'], [1059]);
    expect(filter['#p'], ['pkMe']);
    expect(filter.containsKey('since'), isFalse);
  });

  test('feed honors a custom sync window', () async {
    await isar.writeTxn(
        () => isar.followedUserModels.put(followedUserSeed('pkFollowed')));
    final filter = await FeedNotesSubscription().buildFilter(SubscriptionContext(
        isar: isar,
        activePubkey: 'pkMe',
        recentSyncWindow: const Duration(days: 60)));
    final expectedSince =
        DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
    expect(((filter!['since'] as int) - expectedSince).abs(), lessThan(5));
  });
}
