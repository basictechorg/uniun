import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/gateway/subscriptions/providers/profiles_subscription.dart';
import 'package:uniun/gateway/subscriptions/subscription_provider.dart';
import '../../_helpers/isar_test_harness.dart';

void main() {
  late Isar isar;
  setUp(() async => isar = await openTestIsar());
  tearDown(() async => isar.close(deleteFromDisk: true));

  MissingProfilePubkeyModel missingSeed(String pubkey) =>
      MissingProfilePubkeyModel()
        ..pubkey = pubkey
        ..firstSeenAt = DateTime(2026, 1, 1);

  test('opts out of NIP-77 so kind-0 rides a plain uncapped REQ', () {
    // Negentropy can't be seeded (ProfileModel carries no source event id) and a
    // since=now live-tail would miss historical profiles — so this provider must
    // not use NIP-77.
    expect(ProfilesSubscription().supportsNip77, isFalse);
  });

  test('no filter when nothing is missing', () async {
    final filter = await ProfilesSubscription()
        .buildFilter(SubscriptionContext(isar: isar));
    expect(filter, isNull);
  });

  test('filter pulls all history (no since) for every missing pubkey', () async {
    await isar.writeTxn(() async {
      await isar.missingProfilePubkeyModels.put(missingSeed('pkA'));
      await isar.missingProfilePubkeyModels.put(missingSeed('pkB'));
    });
    final filter = await ProfilesSubscription()
        .buildFilter(SubscriptionContext(isar: isar));

    expect(filter!['kinds'], [0]);
    expect((filter['authors'] as List).toSet(), {'pkA', 'pkB'});
    expect(filter.containsKey('since'), isFalse);
  });
}
