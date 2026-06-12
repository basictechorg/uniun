import 'package:isar_community/isar.dart';

part 'user_server_list_model.g.dart';

/// Single-row Isar collection snapshotting the active user's Kind 10063
/// (BUD-03) preferred Blossom server list. Cached locally so we don't walk
/// the event log to find the publish target on every upload.
@Collection(ignore: {'copyWith'})
@Name('UserServerList')
class UserServerListModel {
  /// Always 0. Single-row collection — there is only ever one active user.
  Id id = 0;

  late List<String> serverUrls;

  /// `created_at` of the Kind 10063 we last accepted. Used by the inbound
  /// handler for last-write-wins reconciliation, mirroring the draft and
  /// profile flows.
  DateTime? lastSyncedCreatedAt;
}
