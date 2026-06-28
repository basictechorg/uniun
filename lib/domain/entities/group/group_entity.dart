import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_entity.freezed.dart';

@freezed
abstract class GroupEntity with _$GroupEntity {
  const factory GroupEntity({
    required String groupId,
    required String creatorPubKey,
    required String name,
    required String about,
    required String picture,
    required List<String> relays,
    required int createdAt,
    required int updatedAt,
    String? lastMetaEvent,
  }) = _GroupEntity;
}
