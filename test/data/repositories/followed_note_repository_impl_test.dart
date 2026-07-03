import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/repositories/followed_note_repository_impl.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';

/// End-to-end tests for [FollowedNoteRepositoryImpl]. Real Isar so the derived
/// `newReferenceCount` join against the edge + unread tables is exercised.
void main() {
  late Isar isar;
  late FollowedNoteRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = FollowedNoteRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<void> seedEdge(String parent, String child) =>
      seedRelationEdge(isar, parent, child);
  Future<void> seedUnread(String eventId, {int kind = 1}) =>
      seedUnreadRow(isar, eventId, kind: kind);

  // ── followNote / unfollowNote ────────────────────────────────────────────

  group('followNote', () {
    test('creates row on first follow', () async {
      final r = await repo.followNote('ev-1', 'preview');
      expect(r.isRight(), isTrue);
      final rows = await isar.followedNoteModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.eventId, 'ev-1');
      expect(rows.single.contentPreview, 'preview');
      expect(rows.single.followedAt, isNotNull);
    });

    test('second follow of same eventId is a no-op Right', () async {
      await repo.followNote('ev-1', 'first-preview');
      await repo.followNote('ev-1', 'second-preview');
      final rows = await isar.followedNoteModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.contentPreview, 'first-preview',
          reason: 'second follow must not overwrite existing metadata');
    });

    test('unicode + emoji + RTL preview persist', () async {
      const payload = '🚨 ${Content.unicode} ${Content.rtl}';
      await repo.followNote('ev-u', payload);
      final row = (await isar.followedNoteModels.where().findAll()).single;
      expect(row.contentPreview, payload);
    });
  });

  group('unfollowNote', () {
    test('removes the row', () async {
      await repo.followNote('ev-1', 'x');
      await repo.unfollowNote('ev-1');
      expect(await isar.followedNoteModels.count(), 0);
    });

    test('unfollow non-existent id is a no-op Right', () async {
      final r = await repo.unfollowNote('ghost');
      expect(r.isRight(), isTrue);
    });
  });

  // ── isFollowed / watchIsFollowed ─────────────────────────────────────────

  group('isFollowed', () {
    test('returns true iff a row exists', () async {
      await repo.followNote('ev-1', 'x');
      expect((await repo.isFollowed('ev-1')).getOrElse(() => false), isTrue);
      expect((await repo.isFollowed('ghost')).getOrElse(() => true), isFalse);
    });
  });

  group('watchIsFollowed', () {
    test('fires immediately + emits false→true→false on follow/unfollow',
        () async {
      final emissions = <bool>[];
      final sub = repo.watchIsFollowed('ev-1').listen(emissions.add);
      // Give Isar's watcher a tick to deliver the initial fire.
      await Future.delayed(const Duration(milliseconds: 30));
      await repo.followNote('ev-1', 'x');
      await Future.delayed(const Duration(milliseconds: 30));
      await repo.unfollowNote('ev-1');
      await Future.delayed(const Duration(milliseconds: 30));
      await sub.cancel();
      expect(emissions.first, isFalse);
      expect(emissions, contains(true));
      expect(emissions.last, isFalse);
    });
  });

  // ── getAll + derived newReferenceCount ───────────────────────────────────

  group('getAll', () {
    test('empty when nothing followed', () async {
      final r = await repo.getAll();
      expect(r.getOrElse(() => throw 'x'), isEmpty);
    });

    test('sorts newest followedAt first', () async {
      await repo.followNote('a', 'A');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.followNote('b', 'B');
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.followNote('c', 'C');
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.map((e) => e.eventId).toList(), ['c', 'b', 'a']);
    });

    test(
        'newReferenceCount = number of children that STILL have a live '
        'unread row', () async {
      await repo.followNote('root', 'r');
      await seedEdge('root', 'child-1');
      await seedEdge('root', 'child-2');
      await seedEdge('root', 'child-3');
      // Only two children are still unread.
      await seedUnread('child-1');
      await seedUnread('child-2');

      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.single.newReferenceCount, 2);
    });

    test('newReferenceCount is 0 when no edges exist', () async {
      await repo.followNote('lonely', 'x');
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.single.newReferenceCount, 0);
    });

    test('newReferenceCount is 0 when edges exist but children are all read',
        () async {
      await repo.followNote('root', 'x');
      await seedEdge('root', 'c-1');
      // No unread row seeded → child is "read".
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.single.newReferenceCount, 0);
    });
  });

  // ── clearNewReferences ───────────────────────────────────────────────────

  group('clearNewReferences', () {
    test(
        'deletes unread rows for every child of the followed note, leaves '
        'unrelated unread rows intact', () async {
      await repo.followNote('root', 'x');
      await seedEdge('root', 'c-1');
      await seedEdge('root', 'c-2');
      await seedUnread('c-1');
      await seedUnread('c-2');
      await seedUnread('unrelated');

      final r = await repo.clearNewReferences('root');
      expect(r.isRight(), isTrue);

      final unreadIds =
          (await isar.unreadNoteModels.where().findAll()).map((u) => u.eventId);
      expect(unreadIds, ['unrelated']);
    });

    test('no-op when the followed note has no edges', () async {
      await repo.followNote('lonely', 'x');
      await seedUnread('random');
      final r = await repo.clearNewReferences('lonely');
      expect(r.isRight(), isTrue);
      expect(await isar.unreadNoteModels.count(), 1);
    });

    test(
        'idempotent: second call after everything cleared still returns Right',
        () async {
      await repo.followNote('root', 'x');
      await seedEdge('root', 'c');
      await seedUnread('c');
      await repo.clearNewReferences('root');
      final r2 = await repo.clearNewReferences('root');
      expect(r2.isRight(), isTrue);
      expect(await isar.unreadNoteModels.count(), 0);
    });

    test('after clearNewReferences, getAll surfaces count = 0', () async {
      await repo.followNote('root', 'x');
      await seedEdge('root', 'c');
      await seedUnread('c');
      await repo.clearNewReferences('root');
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list.single.newReferenceCount, 0);
    });
  });

  // ── Scale ────────────────────────────────────────────────────────────────

  group('scale', () {
    test('50 followed notes + edge/unread joins terminate quickly', () async {
      for (var i = 0; i < 50; i++) {
        await repo.followNote('n-$i', 'preview $i');
        await seedEdge('n-$i', 'c-$i');
        await seedUnread('c-$i');
      }
      final list = (await repo.getAll()).getOrElse(() => throw 'x');
      expect(list, hasLength(50));
      expect(list.every((e) => e.newReferenceCount == 1), isTrue);
    });
  });
}
