import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/gateway/subscriptions/providers/channels_subscription.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'isar_test_harness.dart';

void main() {
  late Isar isar;
  setUp(() async => isar = await openTestIsar());
  tearDown(() async => isar.close(deleteFromDisk: true));

  test('main filter caps messages (kind 42 only) to last 7 days', () async {
    await isar.writeTxn(() => isar.channelModels.put(channelSeed('chan1')));
    final filter =
        await ChannelsSubscription().buildFilter(SubscriptionContext(isar: isar));

    expect(filter!['kinds'], [42]);
    expect(filter['#e'], ['chan1']);
    final expectedSince =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/
            1000;
    expect(((filter['since'] as int) - expectedSince).abs(), lessThan(5));
  });

  test('channel main filter honors a custom sync window', () async {
    await isar.writeTxn(() => isar.channelModels.put(channelSeed('chan1')));
    final filter = await ChannelsSubscription().buildFilter(SubscriptionContext(
        isar: isar, recentSyncWindow: const Duration(days: 60)));
    final expectedSince =
        DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
    expect(((filter!['since'] as int) - expectedSince).abs(), lessThan(5));
  });

  test('companions fetch creation + metadata uncapped', () async {
    await isar.writeTxn(() => isar.channelModels.put(channelSeed('chan1')));
    final companions = await ChannelsSubscription()
        .companionRequests(SubscriptionContext(isar: isar));

    expect(companions.length, 2);

    final info = companions.firstWhere((c) => (c.filter['kinds'] as List).contains(40));
    expect(info.subId, 'channels_info');
    expect(info.filter['ids'], ['chan1']);
    expect(info.filter.containsKey('since'), isFalse);

    final meta = companions.firstWhere((c) => (c.filter['kinds'] as List).contains(41));
    expect(meta.subId, 'channels_meta');
    expect(meta.filter['#e'], ['chan1']);
    expect(meta.filter.containsKey('since'), isFalse);
  });
}
