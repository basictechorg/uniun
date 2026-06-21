import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/gateway/subscriptions/providers/dms_subscription.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import 'isar_test_harness.dart';

void main() {
  late Isar isar;
  setUp(() async => isar = await openTestIsar());
  tearDown(() async => isar.close(deleteFromDisk: true));

  test('provider without companions returns empty list', () async {
    final companions = await DmsSubscription()
        .companionRequests(SubscriptionContext(isar: isar, activePubkey: 'pk'));
    expect(companions, isEmpty);
  });
}
