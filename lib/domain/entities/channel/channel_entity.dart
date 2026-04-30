import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel_entity.freezed.dart';

@freezed
abstract class ChannelEntity with _$ChannelEntity {
  const factory ChannelEntity({
    required String channelId,
    required String creatorPubKey,
    required String name,
    required String about,
    required String picture,
    required List<String> relays,
    required int createdAt,
    required int updatedAt,
    String? lastMetaEvent,
  }) = _ChannelEntity;
}
