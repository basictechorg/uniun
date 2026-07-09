import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/blocked_user_model.dart';
import 'package:uniun/data/repositories/blocked_user_repository_impl.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/stub_user_repository.dart';

/// End-to-end tests for [BlockedUserRepositoryImpl]. Real Isar so the
/// blockedAt sort + unique pubkey guard behave exactly as production.
void main() {
  late Isar isar;
  late BlockedUserRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    // Signer with a logged-out stub — `sign()` returns null so rows are
    // written with `signedNostrEvent = null`. These tests assert on Isar
    // shape only; the wire form is covered by mesh integration tests.
    final signer = MeshEventSigner(StubUserRepository()..keys = null);
    repo = BlockedUserRepositoryImpl(isar: isar, signer: signer);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  // ── blockUser ────────────────────────────────────────────────────────────

  group('blockUser', () {
    test('inserts a row on first block', () async {
      final r = await repo.blockUser(kAlicePub);
      expect(r.isRight(), isTrue);
      final rows = await isar.blockedUserModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.pubkeyHex, kAlicePub);
      expect(rows.single.blockedAt, isNotNull);
    });

    test('second block of same pubkey is a no-op (idempotent)', () async {
      await repo.blockUser(kAlicePub);
      final first = (await isar.blockedUserModels.where().findAll()).single;
      await Future.delayed(const Duration(milliseconds: 10));
      await repo.blockUser(kAlicePub);
      final rows = await isar.blockedUserModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.blockedAt, first.blockedAt,
          reason: 'blockedAt must NOT be refreshed on repeat block');
    });

    test('different pubkeys accumulate', () async {
      await repo.blockUser(kAlicePub);
      await repo.blockUser(kBobPub);
      expect(await isar.blockedUserModels.count(), 2);
    });
  });

  // ── unblockUser ──────────────────────────────────────────────────────────

  group('unblockUser', () {
    test('tombstones the row (mesh-idempotent undo per §5a)', () async {
      await repo.blockUser(kAlicePub);
      final r = await repo.unblockUser(kAlicePub);
      expect(r.isRight(), isTrue);
      // Row survives as a tombstone so mesh negentropy can propagate the
      // "unblock" to peer devices.
      final row = (await isar.blockedUserModels.where().findAll()).single;
      expect(row.removedAt, isNotNull);
      // Repo-level query hides tombstones from the UI.
      final active = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(active, isEmpty);
    });

    test('unblock non-blocked pubkey is a no-op Right', () async {
      final r = await repo.unblockUser('ghost');
      expect(r.isRight(), isTrue);
    });

    test('unblock then re-block works with a fresh blockedAt', () async {
      await repo.blockUser(kAlicePub);
      final first = (await isar.blockedUserModels.where().findAll()).single;
      await repo.unblockUser(kAlicePub);
      await Future.delayed(const Duration(milliseconds: 10));
      await repo.blockUser(kAlicePub);
      final second = (await isar.blockedUserModels.where().findAll()).single;
      expect(second.blockedAt.isAfter(first.blockedAt), isTrue);
    });
  });

  // ── getAll ordering ──────────────────────────────────────────────────────

  group('getAll', () {
    test('empty repo → empty list', () async {
      final r = await repo.getAll();
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw 'x'), isEmpty);
    });

    test('sorts newest blockedAt first', () async {
      await repo.blockUser('a');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.blockUser('b');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.blockUser('c');
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.map((e) => e.pubkeyHex).toList(), ['c', 'b', 'a']);
    });
  });

  // ── Scale ─────────────────────────────────────────────────────────────────

  group('scale', () {
    test('100 blocks + one bulk unblock leaves 100 tombstones, 0 active', () async {
      for (var i = 0; i < 100; i++) {
        await repo.blockUser('pk-$i');
      }
      expect(await isar.blockedUserModels.count(), 100);
      for (var i = 0; i < 100; i++) {
        await repo.unblockUser('pk-$i');
      }
      // Tombstones remain (mesh-syncable), but nothing is active.
      expect(await isar.blockedUserModels.count(), 100);
      final active = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(active, isEmpty);
    });
  });
}
