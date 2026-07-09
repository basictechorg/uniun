import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/datasources/feed_read_state_store.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/data/repositories/feed_repository_impl.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/data/repositories/source_label_repository_impl.dart';
import 'package:uniun/data/repositories/storage_repository_impl.dart';
import 'package:uniun/data/repositories/unread_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/isar_seeds.dart';
import '../_helpers/isar_test_harness.dart';
import '../_helpers/stub_followed_users.dart';
import '../_helpers/stub_user_repository.dart';

/// End-to-end feed read lifecycle — the Telegram-style unread flow from
/// "note arrives over the wire" to "user has read everything and purges
/// old content". Arrivals go through [putUnreadRowInTxn], the SAME
/// projection writer the Gateway inbound handlers use, so this exercises
/// the real inbound → unread → banner → drain → seen → purge chain over
/// one real Isar. Only identity and the follow list are stubbed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late FeedRepositoryImpl feed;
  late UnreadRepositoryImpl unread;
  late StorageRepositoryImpl storage;

  setUp(() async {
    isar = await openTestIsar();
    SharedPreferences.setMockInitialValues({});
    final user = StubUserRepository()
      ..keys = (privkeyHex: kTestPrivHex, pubkeyHex: kSelfPub);
    final relations = NoteRelationRepositoryImpl(isar: isar);
    feed = FeedRepositoryImpl(
      isar: isar,
      relations: relations,
      sourceLabels: SourceLabelRepositoryImpl(isar: isar),
      follows: StubFollowedUsers()..pubkeys = [kAlicePub, kBobPub],
      users: user,
      feedReadState: FeedReadStateStore(await SharedPreferences.getInstance()),
      resolver: NoteResolverRepositoryImpl(
        isar: isar,
        relations: relations,
        attachments: NoteAttachmentsEnricher(isar: isar),
      ),
    );
    unread = UnreadRepositoryImpl(isar: isar);
    storage = StorageRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  /// Simulates a Gateway inbound delivery: persists the note AND its unread
  /// projection in one txn via the production [putUnreadRowInTxn].
  Future<void> arrive(
    String eventId, {
    String authorPubkey = kAlicePub,
    int kind = kNoteKind,
    String? groupId,
    DateTime? created,
  }) async {
    final m = noteRow(eventId,
        authorPubkey: authorPubkey,
        kind: kind,
        groupId: groupId,
        created: created);
    await isar.writeTxn(() async {
      await isar.noteModels.put(m);
      await putUnreadRowInTxn(isar, m);
    });
  }

  List<String> idsOf(dynamic either) =>
      (either.getOrElse(() => const <NoteEntity>[]) as List<NoteEntity>)
          .map((n) => n.id)
          .toList();

  test(
      'SCENARIO: arrivals → banner counts them → user drains the unread '
      'queue → banner clears → notes reappear in the seen bucket', () async {
    // 1. App opens; the anchor snapshots "now".
    final loadedAt = tNow.subtract(const Duration(hours: 1));
    await feed.setFeedLoadedAt(loadedAt);

    // 2. Three notes arrive after the anchor, one is ancient history.
    await arrive('new-1', created: tNow);
    await arrive('new-2', created: tNow.subtract(const Duration(minutes: 5)));
    await arrive('new-3',
        authorPubkey: kBobPub,
        created: tNow.subtract(const Duration(minutes: 10)));
    await arrive('old-1', created: tNow.subtract(const Duration(days: 1)));

    // 3. Banner: only arrivals newer than the anchor count.
    expect(await feed.watchNewBufferCount(loadedAt).first, 3);

    // 4. The unread queue serves everything unread, newest first.
    final page = await feed.getUnread(limit: 10, excludeIds: {});
    expect(idsOf(page), ['new-1', 'new-2', 'new-3', 'old-1']);

    // 5. The user scrolls through — each visible note is marked seen.
    for (final id in ['new-1', 'new-2', 'new-3', 'old-1']) {
      expect((await unread.markSeen(id)).isRight(), isTrue);
    }

    // 6. Queue empty, banner zero, all four now in the seen bucket.
    expect(idsOf(await feed.getUnread(limit: 10, excludeIds: {})), isEmpty);
    expect(await feed.watchNewBufferCount(loadedAt).first, 0);
    expect(idsOf(await feed.getSeen(limit: 10)),
        ['new-1', 'new-2', 'new-3', 'old-1']);
  });

  test(
      'SCENARIO: reader mid-scroll — excludeIds keeps the already-rendered '
      'cards out while newer arrivals slot in on the next pull', () async {
    await arrive('first', created: tNow.subtract(const Duration(minutes: 1)));
    final page1 = await feed.getUnread(limit: 10, excludeIds: {});
    expect(idsOf(page1), ['first']);

    // A new note lands while the user is reading.
    await arrive('breaking', created: tNow);

    final page2 = await feed.getUnread(limit: 10, excludeIds: {'first'});
    expect(idsOf(page2), ['breaking']);
  });

  test(
      'SCENARIO: group message lifecycle — arrival bumps the drawer state, '
      'opening the group clears it via markGroupSeen', () async {
    await arrive('gm-1',
        kind: kGroupMessageKind,
        groupId: 'g-1',
        authorPubkey: kEvePub,
        created: tT0);
    await arrive('gm-2',
        kind: kGroupMessageKind, groupId: 'g-1', authorPubkey: kEvePub);
    await arrive('other-group',
        kind: kGroupMessageKind, groupId: 'g-2', authorPubkey: kEvePub);

    // Jump-to-first-unread anchor = the oldest unread in that group.
    final oldest = await unread.oldestUnreadTimeForGroup('g-1');
    expect(oldest.getOrElse(() => null)!.isAtSameMomentAs(tT0), isTrue);

    // Opening the group clears exactly that group's rows.
    expect((await unread.markGroupSeen('g-1')).isRight(), isTrue);
    expect(
        (await unread.oldestUnreadTimeForGroup('g-1')).getOrElse(() => tNow),
        isNull);
    expect(await isar.unreadNoteModels.count(), 1); // g-2 untouched

    // Group messages remain feed-eligible in the seen bucket.
    expect(idsOf(await feed.getSeen(limit: 10)), contains('gm-1'));
  });

  test(
      'SCENARIO: storage purge after reading — deletes foreign feed notes '
      'but never own/saved/followed, and the feed reflects it immediately',
      () async {
    await arrive('disposable-1');
    await arrive('disposable-2', authorPubkey: kBobPub);
    await arrive('own-note', authorPubkey: kSelfPub);
    await arrive('keep-saved');
    await arrive('keep-followed', authorPubkey: kBobPub);
    await isar.writeTxn(() async {
      await isar.savedNoteModels.put(savedNoteRow('keep-saved'));
      await isar.followedNoteModels.put(followedNoteSeed('keep-followed'));
    });

    final deleted = await storage.deleteFeedNotes(kSelfPub);
    expect(deleted.getOrElse(() => -1), 2);

    // Unread projections of the purged notes are gone too — no ghost rows
    // feeding the banner.
    final unreadIds = (await isar.unreadNoteModels.where().findAll())
        .map((u) => u.eventId)
        .toSet();
    expect(unreadIds, {'own-note', 'keep-saved', 'keep-followed'});

    final visible = idsOf(await feed.getUnread(limit: 10, excludeIds: {}));
    expect(visible.toSet(), {'own-note', 'keep-saved', 'keep-followed'});
  });

  test(
      'SCENARIO: 60 arrivals paged 20 at a time drain completely with no '
      'duplicates and no gaps', () async {
    for (var i = 0; i < 60; i++) {
      await arrive('ev-$i', created: tNow.subtract(Duration(minutes: i)));
    }

    final rendered = <String>{};
    while (true) {
      final page =
          await feed.getUnread(limit: 20, excludeIds: Set.of(rendered));
      final ids = idsOf(page);
      if (ids.isEmpty) break;
      // No duplicates across pages.
      expect(rendered.intersection(ids.toSet()), isEmpty);
      rendered.addAll(ids);
    }
    expect(rendered, hasLength(60));
  });
}
