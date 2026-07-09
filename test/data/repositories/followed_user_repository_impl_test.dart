import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/repositories/followed_user_repository_impl.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/recording_event_queue.dart';

/// End-to-end tests for [FollowedUserRepositoryImpl]. Real Isar + a hand-rolled
/// [EventQueueRepository] recorder so we can assert the Kind-3 (NIP-02)
/// contact-list republish that every mutation triggers.
class _MGetKeys extends Mock implements GetActiveUserKeysUseCase {}

void main() {
  late Isar isar;
  late RecordingEventQueue events;
  late _MGetKeys getKeys;
  late FollowedUserRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    events = RecordingEventQueue();
    getKeys = _MGetKeys();
    when(() => getKeys.call())
        .thenAnswer((_) async => const Right(kSigningKeys));
    repo = FollowedUserRepositoryImpl(
      isar: isar,
      eventQueue: events,
      getActiveUserKeys: getKeys,
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  // ── followUser ────────────────────────────────────────────────────────────

  group('followUser', () {
    test('creates row + republishes Kind-3 with the single p-tag', () async {
      final r = await repo.followUser(kAlicePub);
      expect(r.isRight(), isTrue);
      expect(await isar.followedUserModels.count(), 1);
      expect(events.calls, hasLength(1));
      final call = events.calls.single;
      expect(call.kind, 3);
      expect(call.pTagRefs, [kAlicePub]);
      expect(call.eTagRefs, isEmpty);
      expect(call.content, '');
    });

    test('optional relayHint + petname persist on the row', () async {
      await repo.followUser(kAlicePub,
          relayHint: 'wss://relay.example', petname: 'alice');
      final row = (await isar.followedUserModels.where().findAll()).single;
      expect(row.relayHint, 'wss://relay.example');
      expect(row.petname, 'alice');
    });

    test('second follow of same pubkey does NOT insert a duplicate but STILL '
        'republishes (idempotent republish keeps relay in sync)', () async {
      await repo.followUser(kAlicePub);
      await repo.followUser(kAlicePub);
      expect(await isar.followedUserModels.count(), 1);
      expect(events.calls, hasLength(2));
    });

    test('missing active identity → Left, no row, no publish', () async {
      when(() => getKeys.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('no keys')));
      // First insert the row so we exercise the publish failure path only.
      final r = await repo.followUser(kAlicePub);
      expect(r.isLeft(), isTrue);
      expect(events.calls, isEmpty);
    });

    test('enqueue Left propagates', () async {
      events.leftOnEnqueue = const Failure.errorFailure('queue down');
      final r = await repo.followUser(kAlicePub);
      expect(r.isLeft(), isTrue);
    });
  });

  // ── followUsers (batch) ───────────────────────────────────────────────────

  group('followUsers', () {
    test('adds only new pubkeys + republishes ONCE for the whole batch',
        () async {
      await repo.followUser(kAlicePub);
      events.calls.clear();
      // Batch with one already-followed + two new.
      final r = await repo.followUsers([kAlicePub, kBobPub, 'charlie']);
      expect(r.isRight(), isTrue);
      final rows = await isar.followedUserModels.where().findAll();
      expect(rows.map((r) => r.pubkeyHex).toSet(),
          {kAlicePub, kBobPub, 'charlie'});
      expect(events.calls, hasLength(1));
      expect(events.calls.single.pTagRefs.toSet(),
          {kAlicePub, kBobPub, 'charlie'});
    });

    test('empty batch still republishes (keeps relay in sync)', () async {
      final r = await repo.followUsers(const []);
      expect(r.isRight(), isTrue);
      expect(events.calls, hasLength(1));
      expect(events.calls.single.pTagRefs, isEmpty);
    });
  });

  // ── unfollowUser ──────────────────────────────────────────────────────────

  group('unfollowUser', () {
    test('removes row + republishes without the unfollowed p-tag', () async {
      await repo.followUsers([kAlicePub, kBobPub]);
      events.calls.clear();
      final r = await repo.unfollowUser(kAlicePub);
      expect(r.isRight(), isTrue);
      // Soft-delete: alice row is retained with removedAt set (for mesh sync).
      final alice = await isar.followedUserModels
          .where()
          .pubkeyHexEqualTo(kAlicePub)
          .findFirst();
      expect(alice?.removedAt, isNotNull);
      // Active follow list excludes soft-deleted rows.
      final active = (await isar.followedUserModels.where().findAll())
          .where((row) => row.removedAt == null)
          .toList();
      expect(active.map((row) => row.pubkeyHex), [kBobPub]);
      expect(events.calls.single.pTagRefs, [kBobPub]);
    });

    test('unfollow of non-followed pubkey is Right + still republishes',
        () async {
      final r = await repo.unfollowUser('ghost');
      expect(r.isRight(), isTrue);
      expect(events.calls, hasLength(1));
      expect(events.calls.single.pTagRefs, isEmpty);
    });
  });

  // ── isFollowing ───────────────────────────────────────────────────────────

  group('isFollowing', () {
    test('true only after follow, false after unfollow', () async {
      expect((await repo.isFollowing(kAlicePub)).getOrElse(() => true),
          isFalse);
      await repo.followUser(kAlicePub);
      expect(
          (await repo.isFollowing(kAlicePub)).getOrElse(() => false), isTrue);
      await repo.unfollowUser(kAlicePub);
      expect((await repo.isFollowing(kAlicePub)).getOrElse(() => true),
          isFalse);
    });
  });

  // ── getAll / getAllPubkeys ────────────────────────────────────────────────

  group('getters', () {
    test('getAll sorts by followedAt desc', () async {
      await repo.followUser('a');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.followUser('b');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.followUser('c');
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.map((e) => e.pubkeyHex).toList(), ['c', 'b', 'a']);
    });

    test('getAllPubkeys returns the raw set (order-insensitive)', () async {
      await repo.followUsers(['a', 'b']);
      final list = (await repo.getAllPubkeys()).getOrElse(() => throw 'x');
      expect(list.toSet(), {'a', 'b'});
    });
  });

  // ── watchFollowed ─────────────────────────────────────────────────────────

  group('watchFollowed', () {
    test('initial emission is the current list snapshot', () async {
      await repo.followUsers([kAlicePub, kBobPub]);
      final first = await repo.watchFollowed().first
          .timeout(const Duration(seconds: 2));
      expect(first.map((e) => e.pubkeyHex).toSet(), {kAlicePub, kBobPub});
    });
  });

  // ── Kind-3 tag order (NIP-02 signature contract) ──────────────────────────

  group('Kind-3 shape', () {
    test('publishes with p-tag list matching current follow set exactly',
        () async {
      await repo.followUsers(['a', 'b', 'c']); // one batch publish
      await repo.unfollowUser('b'); // one publish
      expect(events.calls, hasLength(2));
      expect(events.calls.last.pTagRefs.toSet(), {'a', 'c'});
    });

    test('Kind-3 event content is always empty string (NIP-02)', () async {
      await repo.followUser(kAlicePub);
      expect(events.calls.single.content, '');
    });
  });

  // ── Edge: unicode / long pubkey / duplicate batch ─────────────────────────

  group('edge cases', () {
    test('petname with unicode + emoji persist verbatim', () async {
      await repo.followUser(kAlicePub, petname: '🚀 ${Content.unicode}');
      final row = (await isar.followedUserModels.where().findAll()).single;
      expect(row.petname, '🚀 ${Content.unicode}');
    });

    test('followUsers with 50 pubkeys all persist + one publish', () async {
      final many = [for (var i = 0; i < 50; i++) 'pk-$i'];
      final r = await repo.followUsers(many);
      expect(r.isRight(), isTrue);
      expect(await isar.followedUserModels.count(), 50);
      expect(events.calls, hasLength(1));
      expect(events.calls.single.pTagRefs, hasLength(50));
    });
  });
}

