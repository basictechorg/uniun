import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';

part 'channel_model.g.dart';

/// Derived from NIP-28 events:
/// - kind 40: channel creation
/// - kind 41: channel metadata update
@Collection(ignore: {'copyWith'})
@Name('Channel')
class ChannelModel {
  Id id = Isar.autoIncrement;

  /// Event id of kind 40 (channel id in NIP-28).
  @Index(unique: true)
  late String channelId;

  /// Pubkey of kind 40 creator.
  late String creatorPubKey;

  late String name;
  late String about;
  late String picture;


  /// All relay URLs associated with this channel.
  late List<String> relays;

  /// Kind 40 created_at (Unix seconds).
  late int createdAt;

  /// Max(created_at) of latest accepted kind 41.
  late int updatedAt;

  /// Event id of the last accepted kind 41.
  String? lastMetaEvent;
}

extension ChannelModelExtension on ChannelModel {
  ChannelEntity toDomain() => ChannelEntity(
        channelId: channelId,
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
