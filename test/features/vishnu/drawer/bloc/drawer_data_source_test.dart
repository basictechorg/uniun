import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/features/vishnu/drawer/bloc/drawer_data_source.dart';

import '../../../../_helpers/isar_test_harness.dart';

GroupModel _aGroup(String groupId) => GroupModel()
  ..groupId = groupId
  ..creatorPubKey = 'creator'
  ..name = 'Test'
  ..about = ''
  ..picture = ''
  ..relays = const []
  ..createdAt = 0
  ..updatedAt = 0;

/// Covers: DrawerDataSource's thin Isar wrapper — each watchLazy() stream
/// actually fires on a write to its own collection, unreadRows()/
/// activeDmConversations()/profileByPubkey() read back what was written,
/// and a removed (tombstoned) DM conversation is excluded from
/// activeDmConversations().
void main() {
  late Isar isar;
  late DrawerDataSource dataSource;

  setUp(() async {
    isar = await openTestIsar();
    dataSource = DrawerDataSource(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('watchGroups fires on a group write', () async {
    final future = dataSource.watchGroups().first;
    await isar.writeTxn(() => isar.groupModels.put(_aGroup('g1')));

    await future.timeout(const Duration(seconds: 2));
  });

  test('watchFollowedUsers fires on a followed-user write', () async {
    final future = dataSource.watchFollowedUsers().first;
    await isar.writeTxn(() => isar.followedUserModels.put(
          FollowedUserModel()
            ..pubkeyHex = 'pk'
            ..followedAt = DateTime(2026, 1, 1),
        ));

    await future.timeout(const Duration(seconds: 2));
  });

  test('watchFollowedNotes fires on a followed-note write', () async {
    final future = dataSource.watchFollowedNotes().first;
    await isar.writeTxn(() => isar.followedNoteModels.put(
          FollowedNoteModel()
            ..eventId = 'n1'
            ..contentPreview = 'preview'
            ..followedAt = DateTime(2026, 1, 1),
        ));

    await future.timeout(const Duration(seconds: 2));
  });

  test('watchUnread fires on an unread-row write', () async {
    final future = dataSource.watchUnread().first;
    await isar.writeTxn(() => isar.unreadNoteModels.put(
          UnreadNoteModel()
            ..eventId = 'n1'
            ..kind = 1
            ..authorPubkey = 'pk'
            ..created = DateTime(2026, 1, 1),
        ));

    await future.timeout(const Duration(seconds: 2));
  });

  test('watchProfiles fires on a profile write', () async {
    final future = dataSource.watchProfiles().first;
    await isar.writeTxn(() => isar.profileModels.put(
          ProfileModel()
            ..pubkey = 'pk'
            ..updatedAt = DateTime(2026, 1, 1),
        ));

    await future.timeout(const Duration(seconds: 2));
  });

  test('watchDmConversations fires on a conversation write', () async {
    final future = dataSource.watchDmConversations().first;
    await isar.writeTxn(() => isar.dmConversationModels.put(
          DmConversationModel()..otherPubkey = 'peer',
        ));

    await future.timeout(const Duration(seconds: 2));
  });

  test('unreadRows returns every written row', () async {
    await isar.writeTxn(() async {
      await isar.unreadNoteModels.put(UnreadNoteModel()
        ..eventId = 'n1'
        ..kind = 1
        ..authorPubkey = 'pk'
        ..created = DateTime(2026, 1, 1));
      await isar.unreadNoteModels.put(UnreadNoteModel()
        ..eventId = 'n2'
        ..kind = 1
        ..authorPubkey = 'pk'
        ..created = DateTime(2026, 1, 1));
    });

    final rows = await dataSource.unreadRows();

    expect(rows, hasLength(2));
  });

  test('activeDmConversations excludes a removed (tombstoned) conversation',
      () async {
    await isar.writeTxn(() async {
      await isar.dmConversationModels.put(DmConversationModel()..otherPubkey = 'active');
      await isar.dmConversationModels.put(DmConversationModel()
        ..otherPubkey = 'removed'
        ..removedAt = DateTime(2026, 1, 1));
    });

    final conversations = await dataSource.activeDmConversations();

    expect(conversations.map((c) => c.otherPubkey), ['active']);
  });

  test('profileByPubkey resolves an existing profile and null for a '
      'missing one', () async {
    await isar.writeTxn(() => isar.profileModels.put(
          ProfileModel()
            ..pubkey = 'pk'
            ..name = 'Alice'
            ..updatedAt = DateTime(2026, 1, 1),
        ));

    final found = await dataSource.profileByPubkey('pk');
    final missing = await dataSource.profileByPubkey('nobody');

    expect(found?.name, 'Alice');
    expect(missing, isNull);
  });
}
