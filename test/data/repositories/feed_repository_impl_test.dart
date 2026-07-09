import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/datasources/feed_read_state_store.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/repositories/feed_repository_impl.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/data/repositories/source_label_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/stub_followed_users.dart';
import '../../_helpers/stub_user_repository.dart';

/// Covers: FeedRepositoryImpl getUnread/getSeen (kind eligibility, author
/// allow-list, excludeIds, cursor pagination, ordering), markSeen, the
/// feedLoadedAt anchor, watchNewBufferCount, source labels and edge counts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late StubUserRepository user;
  late StubFollowedUsers follows;
  late FeedRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    SharedPreferences.setMockInitialValues({});
    user = StubUserRepository()
      ..keys = (privkeyHex: kTestPrivHex, pubkeyHex: kSelfPub);
    follows = StubFollowedUsers()..pubkeys = [kAlicePub];
    final relations = NoteRelationRepositoryImpl(isar: isar);
    repo = FeedRepositoryImpl(
      isar: isar,
      relations: relations,
      sourceLabels: SourceLabelRepositoryImpl(isar: isar),
      follows: follows,
      users: user,
      feedReadState: FeedReadStateStore(await SharedPreferences.getInstance()),
      resolver: NoteResolverRepositoryImpl(
        isar: isar,
        relations: relations,
        attachments: NoteAttachmentsEnricher(isar: isar),
      ),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  /// Seeds a note + its unread projection row in one go.
  Future<void> seedUnreadNote(
    String eventId, {
    int kind = kNoteKind,
    String authorPubkey = kAlicePub,
    String? groupId,
    String? privateGroupId,
    int? conversationId,
    DateTime? created,
  }) async {
    await seedNoteRow(isar, eventId,
        kind: kind,
        authorPubkey: authorPubkey,
        groupId: groupId,
        privateGroupId: privateGroupId,
        conversationId: conversationId,
        created: created);
    await seedUnreadRow(isar, eventId,
        kind: kind,
        authorPubkey: authorPubkey,
        groupId: groupId,
        privateGroupId: privateGroupId,
        conversationId: conversationId,
        created: created);
  }

  List<String> idsOf(dynamic either) =>
      (either.getOrElse(() => const <NoteEntity>[]) as List<NoteEntity>)
          .map((n) => n.id)
          .toList();

  // ── getUnread ───────────────────────────────────────────────────────────────

  group('getUnread', () {
    test('returns unread feed notes newest-first', () async {
      await seedUnreadNote('old', created: tNow.subtract(const Duration(hours: 2)));
      await seedUnreadNote('mid', created: tNow.subtract(const Duration(hours: 1)));
      await seedUnreadNote('new', created: tNow);

      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(idsOf(r), ['new', 'mid', 'old']);
    });

    test('kind 1 gated to own + followed authors; strangers dropped',
        () async {
      await seedUnreadNote('own', authorPubkey: kSelfPub);
      await seedUnreadNote('followed', authorPubkey: kAlicePub);
      await seedUnreadNote('stranger', authorPubkey: kEvePub);

      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(idsOf(r), containsAll(['own', 'followed']));
      expect(idsOf(r), isNot(contains('stranger')));
    });

    test('kind 42 / 9023 are NOT author-gated (any group member appears)',
        () async {
      await seedUnreadNote('gm',
          kind: kGroupMessageKind, authorPubkey: kEvePub, groupId: 'g-1');
      await seedUnreadNote('pgm',
          kind: kPrivateGroupKind,
          authorPubkey: kEvePub,
          privateGroupId: 'pg-1');

      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(idsOf(r), containsAll(['gm', 'pgm']));
    });

    test('DM kinds (14/15) never appear', () async {
      await seedUnreadNote('dm-text', kind: kDmTextKind, conversationId: 1);
      await seedUnreadNote('dm-file', kind: kDmFileKind, conversationId: 1);
      await seedUnreadNote('note');

      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(idsOf(r), ['note']);
    });

    test('excludeIds skips already-loaded rows without shorting the page',
        () async {
      for (var i = 0; i < 6; i++) {
        await seedUnreadNote('ev-$i',
            created: tNow.subtract(Duration(minutes: i)));
      }
      final r = await repo.getUnread(
          limit: 3, excludeIds: {'ev-0', 'ev-1', 'ev-2'});
      expect(idsOf(r), ['ev-3', 'ev-4', 'ev-5']);
    });

    test('limit honored when more unread rows exist', () async {
      for (var i = 0; i < 10; i++) {
        await seedUnreadNote('ev-$i',
            created: tNow.subtract(Duration(minutes: i)));
      }
      final r = await repo.getUnread(limit: 4, excludeIds: {});
      expect(idsOf(r), hasLength(4));
    });

    test('unread row without a backing Note row is silently dropped',
        () async {
      await seedUnreadRow(isar, 'ghost');
      await seedUnreadNote('real');

      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(idsOf(r), ['real']);
    });

    test('empty database → Right(empty)', () async {
      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(r.isRight(), isTrue);
      expect(idsOf(r), isEmpty);
    });

    test('follow removal takes effect immediately (live re-filter)', () async {
      await seedUnreadNote('alice-note', authorPubkey: kAlicePub);
      await seedUnreadNote('bob-note', authorPubkey: kBobPub);
      follows.pubkeys = [kBobPub];

      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(idsOf(r), ['bob-note']);
    });

    test('fully empty allow-list disables the kind-1 gate (anyOf([]) quirk)',
        () async {
      // Current behaviour: Isar's `anyOf` over an empty list matches ALL
      // rows, so a logged-out user with zero follows sees every kind-1 —
      // NOT the "impossible filter" the impl comment claims. Unreachable in
      // production (a signed-in user always contributes their own pubkey).
      user.keys = null;
      follows.pubkeys = const [];
      await seedUnreadNote('anyone', authorPubkey: kEvePub);

      final r = await repo.getUnread(limit: 10, excludeIds: {});
      expect(idsOf(r), ['anyone']);
    });
  });

  // ── getSeen ─────────────────────────────────────────────────────────────────

  group('getSeen', () {
    test('returns notes with NO unread row, newest-first', () async {
      await seedNoteRow(isar, 'seen-1',
          created: tNow.subtract(const Duration(hours: 1)));
      await seedNoteRow(isar, 'seen-2', created: tNow);
      await seedUnreadNote('unread-1',
          created: tNow.subtract(const Duration(minutes: 30)));

      final r = await repo.getSeen(limit: 10);
      expect(idsOf(r), ['seen-2', 'seen-1']);
    });

    test('before cursor pages backwards through the seen bucket', () async {
      for (var i = 0; i < 6; i++) {
        await seedNoteRow(isar, 'ev-$i',
            created: tNow.subtract(Duration(hours: i)));
      }
      final page1 = await repo.getSeen(limit: 3);
      expect(idsOf(page1), ['ev-0', 'ev-1', 'ev-2']);

      final page2 = await repo.getSeen(
          limit: 3, before: tNow.subtract(const Duration(hours: 3)));
      // Cursor is inclusive — the note AT the cursor timestamp is returned.
      expect(idsOf(page2), ['ev-3', 'ev-4', 'ev-5']);
    });

    test('a run of unread rows never falsely exhausts the bucket', () async {
      // 8 unread (newest) then 3 seen (older) with limit 3 — the loop must
      // page past the unread run and still fill the page.
      for (var i = 0; i < 8; i++) {
        await seedUnreadNote('unread-$i',
            created: tNow.subtract(Duration(minutes: i)));
      }
      for (var i = 0; i < 3; i++) {
        await seedNoteRow(isar, 'seen-$i',
            created: tNow.subtract(Duration(hours: 1 + i)));
      }
      final r = await repo.getSeen(limit: 3);
      expect(idsOf(r), ['seen-0', 'seen-1', 'seen-2']);
    });

    test('kind 1 author gate applies to the seen bucket too', () async {
      await seedNoteRow(isar, 'stranger', authorPubkey: kEvePub);
      await seedNoteRow(isar, 'followed', authorPubkey: kAlicePub);

      final r = await repo.getSeen(limit: 10);
      expect(idsOf(r), ['followed']);
    });

    test('DM rows in the Note collection never surface as seen', () async {
      await seedNoteRow(isar, 'dm', kind: kDmTextKind, conversationId: 1);
      final r = await repo.getSeen(limit: 10);
      expect(idsOf(r), isEmpty);
    });
  });

  // ── Entity enrichment ───────────────────────────────────────────────────────

  group('entity enrichment', () {
    test('reply/reference counts come from the edge table', () async {
      await seedNoteRow(isar, 'popular');
      await seedRelationEdge(isar, 'popular', 'child-1');
      await seedRelationEdge(isar, 'popular', 'child-2');
      await seedRelationEdge(isar, 'parent-x', 'popular');

      final r = await repo.getSeen(limit: 10);
      final note = r.getOrElse(() => const <NoteEntity>[]).single;
      expect(note.cachedReplyCount, 2);
      expect(note.referenceCount, 1);
    });

    test('group message carries its group name as sourceLabel', () async {
      await isar.writeTxn(() async {
        await isar.groupModels.put(groupSeed('g-1')..name = 'Design Talk');
      });
      await seedNoteRow(isar, 'gm',
          kind: kGroupMessageKind, authorPubkey: kEvePub, groupId: 'g-1');

      final r = await repo.getSeen(limit: 10);
      final note = r.getOrElse(() => const <NoteEntity>[]).single;
      expect(note.sourceLabel, 'Design Talk');
    });

    test('unknown group id falls back to the generic label', () async {
      await seedNoteRow(isar, 'gm',
          kind: kGroupMessageKind, authorPubkey: kEvePub, groupId: 'nowhere');

      final r = await repo.getSeen(limit: 10);
      final note = r.getOrElse(() => const <NoteEntity>[]).single;
      expect(note.sourceLabel, isNotNull);
    });

    test('plain kind-1 note has no sourceLabel', () async {
      await seedNoteRow(isar, 'plain');
      final r = await repo.getSeen(limit: 10);
      expect(r.getOrElse(() => const <NoteEntity>[]).single.sourceLabel,
          isNull);
    });
  });

  // ── markSeen ────────────────────────────────────────────────────────────────

  group('markSeen', () {
    test('deletes the unread row; note moves from unread to seen bucket',
        () async {
      await seedUnreadNote('ev-1');
      expect(idsOf(await repo.getUnread(limit: 10, excludeIds: {})), ['ev-1']);

      final r = await repo.markSeen('ev-1');
      expect(r.isRight(), isTrue);
      expect(idsOf(await repo.getUnread(limit: 10, excludeIds: {})), isEmpty);
      expect(idsOf(await repo.getSeen(limit: 10)), ['ev-1']);
    });

    test('idempotent on unknown eventId', () async {
      final r = await repo.markSeen('never-existed');
      expect(r.isRight(), isTrue);
    });
  });

  // ── feedLoadedAt anchor ─────────────────────────────────────────────────────

  group('feedLoadedAt anchor', () {
    test('getOrInit creates the anchor once, then returns the stored value',
        () async {
      final first = await repo.getOrInitFeedLoadedAt();
      final second = await repo.getOrInitFeedLoadedAt();
      // The store persists epoch millis — compare at millisecond precision.
      expect(
        first.getOrElse(() => tT0).millisecondsSinceEpoch,
        second.getOrElse(() => tNow).millisecondsSinceEpoch,
      );
    });

    test('setFeedLoadedAt snaps the anchor forward', () async {
      final ts = DateTime(2026, 7, 1, 9, 30);
      expect((await repo.setFeedLoadedAt(ts)).isRight(), isTrue);
      final read = await repo.getOrInitFeedLoadedAt();
      expect(read.getOrElse(() => tT0), ts);
    });
  });

  // ── watchNewBufferCount ─────────────────────────────────────────────────────

  group('watchNewBufferCount', () {
    test('first emission counts unread arrivals newer than loadedAt',
        () async {
      final loadedAt = tNow.subtract(const Duration(hours: 1));
      await seedUnreadNote('older',
          created: tNow.subtract(const Duration(hours: 2)));
      await seedUnreadNote('newer-1', created: tNow);
      await seedUnreadNote('newer-2',
          created: tNow.subtract(const Duration(minutes: 5)));
      // Stranger kind-1 arrival must not count.
      await seedUnreadNote('stranger', authorPubkey: kEvePub, created: tNow);

      final n = await repo
          .watchNewBufferCount(loadedAt)
          .first
          .timeout(const Duration(seconds: 5));
      expect(n, 2);
    });

    test('emits 0 when nothing is newer than loadedAt', () async {
      await seedUnreadNote('old',
          created: tNow.subtract(const Duration(days: 1)));
      final n = await repo
          .watchNewBufferCount(tNow)
          .first
          .timeout(const Duration(seconds: 5));
      expect(n, 0);
    });
  });
}
