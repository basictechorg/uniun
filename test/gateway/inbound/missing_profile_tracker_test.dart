import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/gateway/inbound/missing_profile_tracker.dart';
import '../../_helpers/isar_test_harness.dart';

void main() {
  late Isar isar;
  late MissingProfileTracker tracker;
  setUp(() async {
    isar = await openTestIsar();
    tracker = MissingProfileTracker(isar);
  });
  tearDown(() async => isar.close(deleteFromDisk: true));

  Map<String, dynamic> event({required int kind, required String pubkey}) =>
      {'kind': kind, 'pubkey': pubkey, 'id': 'id_$pubkey'};

  Future<List<String>> missingPubkeys() async =>
      (await isar.missingProfilePubkeyModels.where().findAll())
          .map((m) => m.pubkey)
          .toList();

  test('tracks an unseen author of a kind-1 note', () async {
    await tracker.track(event(kind: 1, pubkey: 'pkAuthor'));
    expect(await missingPubkeys(), ['pkAuthor']);
  });

  test('skips kind 0 — the profile event itself (avoids the refetch race)',
      () async {
    // Tracking the kind-0 author races Kind0ProfileHandler, which deletes the
    // missing row in the same inbound pass; re-adding it loops the fetch.
    await tracker.track(event(kind: 0, pubkey: 'pkProfile'));
    expect(await missingPubkeys(), isEmpty);
  });

  test('skips kind 1059 — ephemeral gift-wrap pubkey (avoids junk)', () async {
    // 1059 `pubkey` is an ephemeral wrapper key with no kind-0; it would never
    // resolve and would grow the profiles REQ author list unbounded.
    await tracker.track(event(kind: 1059, pubkey: 'pkEphemeral'));
    expect(await missingPubkeys(), isEmpty);
  });

  test('does not track a pubkey we already have a profile for', () async {
    await isar.writeTxn(() => isar.profileModels.put(
          ProfileModel()
            ..pubkey = 'pkKnown'
            ..updatedAt = DateTime(2026, 1, 1),
        ));
    await tracker.track(event(kind: 1, pubkey: 'pkKnown'));
    expect(await missingPubkeys(), isEmpty);
  });

  test('is idempotent — same pubkey tracked twice yields one row', () async {
    await tracker.track(event(kind: 1, pubkey: 'pkDup'));
    await tracker.track(event(kind: 1, pubkey: 'pkDup'));
    expect(await missingPubkeys(), ['pkDup']);
  });

  test('trackPubkey still records direct (decrypt-path) senders', () async {
    // DM / MLS decrypt paths feed the real sender pubkey here, bypassing the
    // kind-based skip — those must still be tracked.
    await tracker.trackPubkey('pkSender');
    expect(await missingPubkeys(), ['pkSender']);
  });
}
