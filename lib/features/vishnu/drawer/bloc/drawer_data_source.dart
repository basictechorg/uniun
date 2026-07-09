import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/models/profile_model.dart';

@injectable
class DrawerDataSource {
  const DrawerDataSource(this._isar);

  final Isar _isar;

  Stream<void> watchGroups() => _isar.groupModels.watchLazy();
  Stream<void> watchFollowedUsers() => _isar.followedUserModels.watchLazy();
  Stream<void> watchFollowedNotes() => _isar.followedNoteModels.watchLazy();
  Stream<void> watchUnread() => _isar.unreadNoteModels.watchLazy();
  Stream<void> watchProfiles() => _isar.profileModels.watchLazy();
  Stream<void> watchDmConversations() => _isar.dmConversationModels.watchLazy();

  Future<List<UnreadNoteModel>> unreadRows() =>
      _isar.unreadNoteModels.where().findAll();

  Future<List<DmConversationModel>> activeDmConversations() =>
      _isar.dmConversationModels.filter().removedAtIsNull().findAll();

  Future<ProfileModel?> profileByPubkey(String pubkey) =>
      _isar.profileModels.where().pubkeyEqualTo(pubkey).findFirst();
}
