import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';

part 'followed_user_model.g.dart';

/// Local persistence for users the active identity is following (NIP-02 Kind 3).
///
/// Source of truth is the Nostr Kind 3 event for our own pubkey; this table is
/// reconciled on every inbound Kind 3 (see `kind3_contact_list_handler.dart`)
/// using last-write-wins by `created_at`.
@Collection(ignore: {'copyWith'})
@Name('FollowedUser')
class FollowedUserModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String pubkeyHex;

  String? relayHint;
  String? petname;
  late DateTime followedAt;

  /// `created_at` of the Kind 3 event that produced this row's current state.
  /// Used by the handler to reject older Kind 3 events. Null = locally-added
  /// row that hasn't been confirmed back from a relay yet.
  DateTime? lastKind3CreatedAt;
}

extension FollowedUserModelExtension on FollowedUserModel {
  FollowedUserEntity toDomain() => FollowedUserEntity(
        pubkeyHex: pubkeyHex,
        relayHint: relayHint,
        petname: petname,
        followedAt: followedAt,
      );
}
