import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/gateway/subscriptions/providers/private_groups_subscription.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import '../../_helpers/isar_test_harness.dart';

void main() {
  late Isar isar;
  setUp(() async => isar = await openTestIsar());
  tearDown(() async => isar.close(deleteFromDisk: true));

  test('main filter caps application messages (9023) to last 7 days', () async {
    await isar.writeTxn(
        () => isar.privateGroupModels.put(privateGroupSeed('grp1')));
    final filter = await PrivateGroupsSubscription()
        .buildFilter(SubscriptionContext(isar: isar));

    expect(filter!['kinds'], [9023]);
    expect(filter['#h'], ['grp1']);
    final expectedSince = (DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch ~/
        1000);
    expect(((filter['since'] as int) - expectedSince).abs(), lessThan(5));
  });

  test('private-group messages honor a custom sync window', () async {
    await isar.writeTxn(
        () => isar.privateGroupModels.put(privateGroupSeed('grp1')));
    final filter = await PrivateGroupsSubscription().buildFilter(
        SubscriptionContext(
            isar: isar, recentSyncWindow: const Duration(days: 60)));
    final expectedSince =
        DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
    expect(((filter!['since'] as int) - expectedSince).abs(), lessThan(5));
  });

  test('MLS control plane + metadata companions are uncapped', () async {
    await isar.writeTxn(
        () => isar.privateGroupModels.put(privateGroupSeed('grp1')));
    final companions = await PrivateGroupsSubscription()
        .companionRequests(SubscriptionContext(isar: isar));

    expect(companions.length, 2);

    final meta =
        companions.firstWhere((c) => (c.filter['kinds'] as List).contains(9002));
    expect(meta.subId, 'private_groups_meta');
    expect(meta.filter['ids'], ['grp1']);
    expect(meta.filter.containsKey('since'), isFalse);

    final mls =
        companions.firstWhere((c) => (c.filter['kinds'] as List).contains(9025));
    expect(mls.subId, 'private_groups_mls');
    expect(mls.filter['kinds'], [9021, 9022, 9024, 9025]);
    expect(mls.filter['#h'], ['grp1']);
    expect(mls.filter.containsKey('since'), isFalse);
  });
}
