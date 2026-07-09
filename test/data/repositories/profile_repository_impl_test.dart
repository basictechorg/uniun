import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/data/repositories/profile_repository_impl.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: ProfileRepositoryImpl getProfile / saveProfile upsert /
/// getOwnProfile / watchProfile / requestProfileFetch dedup, plus the
/// own-profile eviction sentinel round-trip.
void main() {
  late Isar isar;
  late ProfileRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = ProfileRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('getProfile', () {
    test('returns the stored profile mapped to the domain entity', () async {
      await seedProfile(isar, kAlicePub,
          name: 'Alice',
          username: 'alice',
          about: 'hi',
          avatarUrl: 'https://a/1.png',
          nip05: 'alice@uniun.in',
          lastSeenAt: tT0);

      final r = await repo.getProfile(kAlicePub);
      final p = r.getOrElse(() => throw 'unreachable');
      expect(p.pubkey, kAlicePub);
      expect(p.name, 'Alice');
      expect(p.username, 'alice');
      expect(p.about, 'hi');
      expect(p.avatarUrl, 'https://a/1.png');
      expect(p.nip05, 'alice@uniun.in');
      // Isar round-trips DateTime as local time — compare instants.
      expect(p.lastSeenAt!.isAtSameMomentAs(tT0), isTrue);
    });

    test('unknown pubkey → Left(notFoundFailure)', () async {
      final r = await repo.getProfile(kEvePub);
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) => expect(f.toString(), contains(kEvePub)),
        (_) => fail('expected Left'),
      );
    });
  });

  group('saveProfile', () {
    test('inserts a new row and echoes it back as an entity', () async {
      final r = await repo.saveProfile(aProfile(pubkey: kBobPub, name: 'Bob'));
      expect(r.getOrElse(() => throw 'unreachable').name, 'Bob');
      expect(await isar.profileModels.count(), 1);
    });

    test('upserts by pubkey: second save updates the same row', () async {
      await repo.saveProfile(aProfile(pubkey: kBobPub, name: 'Bob'));
      final firstId =
          (await isar.profileModels.where().findAll()).single.id;

      await repo.saveProfile(
          aProfile(pubkey: kBobPub, name: 'Bobby', about: 'updated'));

      final rows = await isar.profileModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.id, firstId);
      expect(rows.single.name, 'Bobby');
      expect(rows.single.about, 'updated');
    });

    test('own-profile eviction sentinel lastSeenAt round-trips', () async {
      await repo.saveProfile(
          aProfile(pubkey: kSelfPub, lastSeenAt: tOwnProfileSentinel));
      final row = (await isar.profileModels.where().findAll()).single;
      expect(row.lastSeenAt!.isAtSameMomentAs(tOwnProfileSentinel), isTrue);
    });

    test('nullable fields can be cleared by a later save', () async {
      await repo.saveProfile(
          aProfile(pubkey: kBobPub, name: 'Bob', about: 'was set'));
      await repo.saveProfile(
          aProfile(pubkey: kBobPub, name: null, about: null));
      final row = (await isar.profileModels.where().findAll()).single;
      expect(row.name, isNull);
      expect(row.about, isNull);
    });

    test('unicode + emoji + RTL profile fields persist verbatim', () async {
      await repo.saveProfile(aProfile(
          pubkey: kAlicePub,
          name: Content.emoji,
          about: '${Content.unicode}\n${Content.rtl}'));
      final row = (await isar.profileModels.where().findAll()).single;
      expect(row.name, Content.emoji);
      expect(row.about, '${Content.unicode}\n${Content.rtl}');
    });
  });

  group('getOwnProfile', () {
    test('returns Right(null) when absent — not a failure', () async {
      final r = await repo.getOwnProfile(kSelfPub);
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw 'unreachable'), isNull);
    });

    test('returns the profile when present', () async {
      await seedProfile(isar, kSelfPub, name: 'Me');
      final r = await repo.getOwnProfile(kSelfPub);
      expect(r.getOrElse(() => null)?.name, 'Me');
    });
  });

  group('watchProfile', () {
    test('fires immediately with null for an unknown pubkey', () async {
      final first = await repo
          .watchProfile(kEvePub)
          .first
          .timeout(const Duration(seconds: 5));
      expect(first, isNull);
    });

    test('fires immediately with the current profile when present', () async {
      await seedProfile(isar, kAlicePub, name: 'Alice');
      final first = await repo
          .watchProfile(kAlicePub)
          .first
          .timeout(const Duration(seconds: 5));
      expect(first?.name, 'Alice');
    });
  });

  group('requestProfileFetch', () {
    Future<List<String>> missingPubkeys() async =>
        (await isar.missingProfilePubkeyModels.where().findAll())
            .map((r) => r.pubkey)
            .toList();

    test('records the pubkey as missing when no profile exists', () async {
      final r = await repo.requestProfileFetch(kEvePub);
      expect(r.isRight(), isTrue);
      expect(await missingPubkeys(), [kEvePub]);
    });

    test('skips when the profile is already stored', () async {
      await seedProfile(isar, kAlicePub);
      final r = await repo.requestProfileFetch(kAlicePub);
      expect(r.isRight(), isTrue);
      expect(await missingPubkeys(), isEmpty);
    });

    test('idempotent: repeat requests keep a single missing row', () async {
      await repo.requestProfileFetch(kEvePub);
      await repo.requestProfileFetch(kEvePub);
      expect(await missingPubkeys(), [kEvePub]);
    });
  });
}
