import 'package:freezed_annotation/freezed_annotation.dart';

part 'blocked_user_entity.freezed.dart';

/// A user the active identity has blocked.
///
/// Blocked users are kept locally forever (never evicted). The gateway isolate
/// drops every inbound Nostr event authored by a blocked `pubkeyHex` before it
/// is persisted, so no new content from that user reaches the app.
@freezed
abstract class BlockedUserEntity with _$BlockedUserEntity {
  const factory BlockedUserEntity({
    required String pubkeyHex,
    required DateTime blockedAt,
  }) = _BlockedUserEntity;
}
