import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/group_message_repository_impl.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/domain/entities/media/media_dim.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: GroupMessageRepositoryImpl save (idempotent + reply edges +
/// attachment mapping), both pagination directions, group scoping, the
/// mention-only eTagRefs contract, and reply lookups.
void main() {
  late Isar isar;
  late GroupMessageRepositoryImpl repo;
  late NoteRelationRepositoryImpl relations;

  setUp(() async {
    isar = await openTestIsar();
    relations = NoteRelationRepositoryImpl(isar: isar);
    repo = GroupMessageRepositoryImpl(
      isar: isar,
      relations: relations,
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

  List<NoteEntity> listOf(dynamic either) =>
      either.getOrElse(() => const <NoteEntity>[]) as List<NoteEntity>;

  group('saveMessage', () {
    test('persists a Kind-42 row bound to the group', () async {
      final r = await repo.saveMessage(
          aGroupMessage(groupId: 'g-1', id: 'gm-1', content: 'hello group'));
      expect(r.isRight(), isTrue);

      final row = (await isar.noteModels.where().findAll()).single;
      expect(row.kind, kGroupMessageKind);
      expect(row.groupId, 'g-1');
      expect(row.content, 'hello group');
    });

    test('relay redelivery is idempotent — first write wins', () async {
      final msg = aGroupMessage(groupId: 'g-1', id: 'gm-1', content: 'v1');
      await repo.saveMessage(msg);
      await repo.saveMessage(msg);
      final r = await repo.saveMessage(msg.copyWith(content: 'tampered'));

      expect(r.getOrElse(() => throw 'unreachable').content, 'v1');
      expect(await isar.noteModels.count(), 1);
    });

    test('reply write lands relation edges for the parent and mentions, '
        'but never the thread root', () async {
      await repo.saveMessage(
          aGroupMessage(groupId: 'g-1', id: 'parent-msg'));
      await repo.saveMessage(aNote(
        id: 'the-reply',
        kind: kGroupMessageKind,
        sourceGroupId: 'g-1',
        rootEventId: 'g-1',
        replyToEventId: 'parent-msg',
        eTagRefs: ['g-1', 'parent-msg', 'mentioned-note'],
      ));

      expect(await relations.replyCount('parent-msg'), 1);
      expect(await relations.replyCount('mentioned-note'), 1);
      // The group root e-tag must not inflate anything.
      expect(await relations.replyCount('g-1'), 0);
    });

    test('attachments map onto the stored row and survive the round trip',
        () async {
      await repo.saveMessage(aGroupMessage(groupId: 'g-1', id: 'gm-1')
          .copyWith(attachments: [
        aMediaBlob(
          sha256: 'sha-img',
          dim: const MediaDim(width: 640, height: 480),
          serverUrls: const ['https://blossom.example/sha-img'],
          filename: 'photo.jpg',
        ),
      ]));

      final row = (await isar.noteModels.where().findAll()).single;
      final a = row.attachments.single;
      expect(a.sha256, 'sha-img');
      expect(a.url, 'https://blossom.example/sha-img');
      expect(a.width, 640);
      expect(a.height, 480);

      final back = (await repo.getMessageByEventId('gm-1'))
          .getOrElse(() => throw 'unreachable')!;
      expect(back.attachments.single.sha256, 'sha-img');
      expect(back.hasMedia, isTrue);
    });

    test('unicode / emoji content round-trips intact', () async {
      await repo.saveMessage(aGroupMessage(
          groupId: 'g-1', id: 'gm-uni', content: Content.unicode));
      final back = (await repo.getMessageByEventId('gm-uni'))
          .getOrElse(() => throw 'unreachable')!;
      expect(back.content, Content.unicode);
    });
  });

  group('eTagRefs contract', () {
    test('entity eTagRefs carries only genuine mentions — group root and '
        'reply parent are stripped', () async {
      await repo.saveMessage(aNote(
        id: 'the-reply',
        kind: kGroupMessageKind,
        sourceGroupId: 'g-1',
        rootEventId: 'g-1',
        replyToEventId: 'parent-msg',
        eTagRefs: ['g-1', 'parent-msg', 'mention-a', 'mention-b'],
      ));

      final page = listOf(await repo.getMessagesForGroup(groupId: 'g-1'));
      expect(page.single.eTagRefs, ['mention-a', 'mention-b']);
      // Threading fields themselves stay available for the UI.
      expect(page.single.replyToEventId, 'parent-msg');
    });
  });

  group('getMessagesForGroup (backwards pagination)', () {
    test('empty group → Right(empty)', () async {
      expect(listOf(await repo.getMessagesForGroup(groupId: 'g-1')), isEmpty);
    });

    test('only this group\'s rows — other groups, feed notes and DMs in the '
        'same collection stay invisible', () async {
      await repo.saveMessage(aGroupMessage(groupId: 'g-1', id: 'mine'));
      await repo.saveMessage(aGroupMessage(groupId: 'g-2', id: 'other'));
      await seedNoteRow(isar, 'feed-note');
      await seedNoteRow(isar, 'dm-note', kind: kDmTextKind, conversationId: 7);

      final page = listOf(await repo.getMessagesForGroup(groupId: 'g-1'));
      expect(page.map((e) => e.id), ['mine']);
    });

    test('45 messages page backwards in three exclusive-cursor pages, '
        'newest first, no duplicates', () async {
      for (var i = 0; i < 45; i++) {
        await repo.saveMessage(aGroupMessage(
          groupId: 'g-1',
          id: 'm-$i',
          created: tNow.subtract(Duration(minutes: i)),
        ));
      }

      final all = <String>[];
      DateTime? cursor;
      while (true) {
        final page = listOf(await repo.getMessagesForGroup(
            groupId: 'g-1', before: cursor, limit: 20));
        if (page.isEmpty) break;
        all.addAll(page.map((e) => e.id));
        cursor = page.last.created;
      }
      expect(all, hasLength(45));
      expect(all.toSet(), hasLength(45));
      expect(all.first, 'm-0'); // newest
      expect(all.last, 'm-44'); // oldest
    });

    test('stitches live reply + reference counts onto each entity',
        () async {
      await repo.saveMessage(aGroupMessage(groupId: 'g-1', id: 'popular'));
      await repo.saveMessage(aNote(
        id: 'r1',
        kind: kGroupMessageKind,
        sourceGroupId: 'g-1',
        rootEventId: 'g-1',
        replyToEventId: 'popular',
        eTagRefs: ['g-1', 'popular'],
        created: tNow.add(const Duration(seconds: 1)),
      ));

      final page = listOf(await repo.getMessagesForGroup(groupId: 'g-1'));
      final popular = page.singleWhere((e) => e.id == 'popular');
      expect(popular.cachedReplyCount, 1);
      final r1 = page.singleWhere((e) => e.id == 'r1');
      expect(r1.referenceCount, 1);
    });
  });

  group('getMessagesForGroupAfter (forward catch-up)', () {
    setUp(() async {
      for (var i = 0; i < 5; i++) {
        await repo.saveMessage(aGroupMessage(
          groupId: 'g-1',
          id: 'm-$i',
          created: tT0.add(Duration(minutes: i)),
        ));
      }
    });

    test('exclusive boundary skips the anchor message itself', () async {
      final page = listOf(await repo.getMessagesForGroupAfter(
          groupId: 'g-1', after: tT0.add(const Duration(minutes: 2))));
      expect(page.map((e) => e.id), ['m-3', 'm-4']);
    });

    test('inclusive boundary re-reads the anchor (jump-to-unread resume)',
        () async {
      final page = listOf(await repo.getMessagesForGroupAfter(
          groupId: 'g-1',
          after: tT0.add(const Duration(minutes: 2)),
          inclusive: true));
      expect(page.map((e) => e.id), ['m-2', 'm-3', 'm-4']);
    });

    test('limit caps the page, oldest first', () async {
      final page = listOf(await repo.getMessagesForGroupAfter(
          groupId: 'g-1', after: tT0.subtract(const Duration(days: 1)),
          limit: 2));
      expect(page.map((e) => e.id), ['m-0', 'm-1']);
    });
  });

  group('getMessageByEventId', () {
    test('unknown id → Right(null), not a failure', () async {
      final r = await repo.getMessageByEventId('nope');
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw 'unreachable'), isNull);
    });
  });

  group('replies', () {
    setUp(() async {
      await repo.saveMessage(aGroupMessage(groupId: 'g-1', id: 'target'));
      await repo.saveMessage(aNote(
        id: 'direct-reply',
        kind: kGroupMessageKind,
        sourceGroupId: 'g-1',
        rootEventId: 'g-1',
        replyToEventId: 'target',
        eTagRefs: ['g-1', 'target'],
        created: tNow.add(const Duration(seconds: 2)),
      ));
      await repo.saveMessage(aNote(
        id: 'mention-ref',
        kind: kGroupMessageKind,
        sourceGroupId: 'g-1',
        eTagRefs: ['target'],
        created: tNow.add(const Duration(seconds: 1)),
      ));
      // A Vishnu feed note e-tagging the message is NOT a group reply.
      await seedNoteRow(isar, 'feed-ref', eTagRefs: ['target']);
    });

    test('getGroupMessageReplies returns direct replies AND mention refs '
        'from group rows only, oldest first', () async {
      final page = listOf(await repo.getGroupMessageReplies('target'));
      expect(page.map((e) => e.id), ['mention-ref', 'direct-reply']);
    });

    test('getGroupMessageReplyCount reads the edge table', () async {
      final r = await repo.getGroupMessageReplyCount('target');
      expect(r.getOrElse(() => -1), 2);
    });
  });
}
