import 'package:freezed_annotation/freezed_annotation.dart';

part 'followed_user_entity.freezed.dart';

/// A user the active identity is following (Nostr Kind 3 contact list entry).
///
/// Followed users are kept locally forever (never evicted) so the Vishnu feed
/// can filter Kind 1 notes by `authorPubkey in followedList`. Sync to remote
/// is via Kind 3 events; the inbound handler reconciles this collection on
/// every Kind 3 from our own pubkey (last-write-wins by `created_at`).
@freezed
abstract class FollowedUserEntity with _$FollowedUserEntity {
  const factory FollowedUserEntity({
    required String pubkeyHex,
    String? relayHint,
    String? petname,
    required DateTime followedAt,
  }) = _FollowedUserEntity;
}
