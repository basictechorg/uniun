import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';

part 'group_model.g.dart';

/// Derived from NIP-28 events:
/// - kind 40: group creation
/// - kind 41: group metadata update
@Collection(ignore: {'copyWith'})
@Name('Channel') // on-disk name preserved across the channel→group rename
class GroupModel {
  Id id = Isar.autoIncrement;

  /// Event id of kind 40 (group id in NIP-28).
  @Name('channelId') // stored name preserved (was ChannelModel.channelId)
  @Index(unique: true)
  late String groupId;

  /// Pubkey of kind 40 creator.
  late String creatorPubKey;

  late String name;
  late String about;
  late String picture;


  /// All relay URLs associated with this group.
  late List<String> relays;

  /// Kind 40 created_at (Unix seconds).
  late int createdAt;

  /// Max(created_at) of latest accepted kind 41.
  late int updatedAt;

  /// Event id of the last accepted kind 41.
  String? lastMetaEvent;
}

extension GroupModelExtension on GroupModel {
  GroupEntity toDomain() => GroupEntity(
        groupId: groupId,
        creatorPubKey: creatorPubKey,
        name: name,
        about: about,
        picture: picture,
        relays: relays,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastMetaEvent: lastMetaEvent,
      );
}
