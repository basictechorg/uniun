import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';

part 'followed_user_model.g.dart';

/// Local persistence for users the active identity is following (NIP-02 Kind 3).
///
/// Relay sync still publishes / consumes the aggregate Kind 3 contact list, but
/// same-identity mesh sync shares one followed user per addressable private
/// record so unfollows can ride as per-pubkey tombstones.
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

  /// Signed+encrypted Nostr Kind 30505 event for this row. Nullable for rows
  /// learned only from a relay Kind 3 before this device mutates them.
  String? signedNostrEvent;

  /// Tombstone marker. Null on active follows.
  @Index()
  DateTime? removedAt;
}

extension FollowedUserModelExtension on FollowedUserModel {
  FollowedUserEntity toDomain() => FollowedUserEntity(
    pubkeyHex: pubkeyHex,
    relayHint: relayHint,
    petname: petname,
    followedAt: followedAt,
  );
}
