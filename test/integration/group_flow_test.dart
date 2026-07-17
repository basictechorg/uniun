import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/repositories/group_message_repository_impl.dart';
import 'package:uniun/data/repositories/group_repository_impl.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/data/repositories/unread_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/isar_seeds.dart';
import '../_helpers/isar_test_harness.dart';
import '../_helpers/mesh_test_helpers.dart';
import '../_helpers/stub_user_repository.dart';

/// End-to-end NIP-28 group scenarios — Kind-40 join through message
/// exchange, threading, unread badges, out-of-order Kind-41 metadata, and
/// the resume path after being offline. Real Isar + real group / group
/// message / unread repositories; only identity is stubbed.
void main() {
  stubSecureStorageChannel();

  late Isar isar;
  late GroupRepositoryImpl groups;
  late GroupMessageRepositoryImpl messages;
  late UnreadRepositoryImpl unread;

  setUp(() async {
    isar = await openTestIsar();
    groups = GroupRepositoryImpl(
      isar: isar,
      signer: MeshEventSigner(StubUserRepository()..keys = null),
    );
    final relations = NoteRelationRepositoryImpl(isar: isar);
    messages = GroupMessageRepositoryImpl(
      isar: isar,
      relations: relations,
      resolver: NoteResolverRepositoryImpl(
        isar: isar,
        relations: relations,
        attachments: NoteAttachmentsEnricher(isar: isar),
      ),
    );
    unread = UnreadRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  List<NoteEntity> listOf(dynamic either) =>
      either.getOrElse(() => const <NoteEntity>[]) as List<NoteEntity>;

  test(
      'SCENARIO: join a group → messages arrive → unread badge → opening '
      'the group clears only ITS badge', () async {
    // 1. User joins via QR: the Kind-40 snapshot lands locally.
    await groups.saveGroup(aGroup(groupId: 'g-1', name: 'General'));

    // 2. Two messages arrive from the relay; the Gateway also lands unread
    //    projections (one per message), plus one in another group.
    await messages.saveMessage(
        aGroupMessage(groupId: 'g-1', id: 'gm-1', authorPubkey: kBobPub));
    await messages.saveMessage(aGroupMessage(
        groupId: 'g-1',
        id: 'gm-2',
        authorPubkey: kCarolPub,
        created: tNow.add(const Duration(minutes: 1))));
    await seedUnreadRow(isar, 'gm-1',
        kind: kGroupMessageKind, groupId: 'g-1', authorPubkey: kBobPub);
    await seedUnreadRow(isar, 'gm-2',
        kind: kGroupMessageKind, groupId: 'g-1', authorPubkey: kCarolPub);
    await seedUnreadRow(isar, 'other-gm',
        kind: kGroupMessageKind, groupId: 'g-2');

    expect(await isar.unreadNoteModels.count(), 3);

    // 3. Opening the group shows the chat newest-first and clears its badge —
    //    the other group's badge survives.
    final page = listOf(await messages.getMessagesForGroup(groupId: 'g-1'));
    expect(page.map((e) => e.id).toList(), ['gm-2', 'gm-1']);
    expect((await unread.markGroupSeen('g-1')).isRight(), isTrue);

    final leftovers = await isar.unreadNoteModels.where().findAll();
    expect(leftovers.map((u) => u.eventId), ['other-gm']);
  });

  test(
      'SCENARIO: threaded group conversation — reply and mention wiring '
      'drives live counts on the message list', () async {
    await groups.saveGroup(aGroup(groupId: 'g-1'));
    await messages.saveMessage(
        aGroupMessage(groupId: 'g-1', id: 'question', content: 'anyone?'));
    // Bob replies (NIP-10: root = group id, reply = the message).
    await messages.saveMessage(aNote(
      id: 'answer',
      kind: kGroupMessageKind,
      sourceGroupId: 'g-1',
      authorPubkey: kBobPub,
      rootEventId: 'g-1',
      replyToEventId: 'question',
      eTagRefs: ['g-1', 'question'],
      created: tNow.add(const Duration(minutes: 1)),
    ));

    final page = listOf(await messages.getMessagesForGroup(groupId: 'g-1'));
    expect(page.singleWhere((e) => e.id == 'question').cachedReplyCount, 1);

    final thread = listOf(await messages.getGroupMessageReplies('question'));
    expect(thread.map((e) => e.id), ['answer']);
    // The reply renders with clean mention refs (root/parent stripped).
    expect(thread.single.eTagRefs, isEmpty);
  });

  test(
      'SCENARIO: relay replays history out of order — stale Kind-41 rename '
      'arriving after a newer one never wins', () async {
    await groups.saveGroup(aGroup(groupId: 'g-1', name: 'Original'));

    // Newer rename applies first (relays don't guarantee order)…
    await groups.updateGroupMetadata(
        'g-1', 'meta-new', 1720002000, 'Newest Name', 'about', '');
    // …then the older one is replayed and must be dropped.
    await groups.updateGroupMetadata(
        'g-1', 'meta-old', 1720001000, 'Old Name', 'about', '');

    final g = (await groups.getGroupById('g-1'))
        .getOrElse(() => throw 'unreachable');
    expect(g.name, 'Newest Name');
    expect(g.lastMetaEvent, 'meta-new');
  });

  test(
      'SCENARIO: back online after a day — forward catch-up from the last '
      'read message replays exactly the missed messages, oldest first',
      () async {
    await groups.saveGroup(aGroup(groupId: 'g-1'));
    final lastRead = tT0.add(const Duration(hours: 1));
    await messages.saveMessage(
        aGroupMessage(groupId: 'g-1', id: 'seen', created: lastRead));
    for (var i = 0; i < 3; i++) {
      await messages.saveMessage(aGroupMessage(
        groupId: 'g-1',
        id: 'missed-$i',
        created: lastRead.add(Duration(hours: 1 + i)),
      ));
    }

    final resumed = listOf(await messages.getMessagesForGroupAfter(
        groupId: 'g-1', after: lastRead));
    expect(resumed.map((e) => e.id).toList(),
        ['missed-0', 'missed-1', 'missed-2']);
  });

  test(
      'SCENARIO: relay redelivers the whole backlog — every save is '
      'idempotent, chat shows no duplicates', () async {
    await groups.saveGroup(aGroup(groupId: 'g-1'));
    final backlog = [
      for (var i = 0; i < 5; i++)
        aGroupMessage(
            groupId: 'g-1',
            id: 'gm-$i',
            created: tT0.add(Duration(minutes: i))),
    ];
    for (final m in backlog) {
      await messages.saveMessage(m);
    }
    for (final m in backlog.reversed) {
      await messages.saveMessage(m); // full redelivery, reversed order
    }

    expect(await isar.noteModels.count(), 5);
    final page = listOf(await messages.getMessagesForGroup(groupId: 'g-1'));
    expect(page.map((e) => e.id).toSet(), {for (final m in backlog) m.id});
  });
}
