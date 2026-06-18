import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

part 'share_note_input.freezed.dart';

/// The destination a note is being shared into. Each variant maps to one of
/// the existing publish paths (feed / public channel / private channel / DM)
/// so the share repository is a thin dispatcher — it never publishes events
/// directly.
@freezed
sealed class ShareDestination with _$ShareDestination {
  /// Quote-post on the author's own Vishnu feed (Kind 1).
  const factory ShareDestination.feed() = ShareToFeed;

  /// Public NIP-28 channel message (Kind 42).
  const factory ShareDestination.publicChannel({
    required String channelId,
  }) = ShareToPublicChannel;

  /// Private MLS-encrypted channel message (Kind 9023).
  const factory ShareDestination.privateChannel({
    required String groupId,
  }) = ShareToPrivateChannel;

  /// NIP-17 DM to a specific peer (Kind 14 inside Kind 1059 gift-wrap).
  const factory ShareDestination.dm({
    required String otherPubkeyHex,
  }) = ShareToDm;
}

@freezed
abstract class ShareNoteInput with _$ShareNoteInput {
  const factory ShareNoteInput({
    /// Event id of the note being shared. Resolved by the repository so it can
    /// snapshot the original into the outgoing event's `embeddedNoteJson` tag.
    required String sourceEventId,
    required ShareDestination destination,

    /// The user's own composed note text published alongside the embed. May be
    /// empty. `#hashtags` in it become `t` tags on the feed surface.
    @Default('') String content,

    /// Event ids of notes the user referenced in the composer → NIP-10 `e`
    /// mention tags on the outgoing share.
    @Default(<String>[]) List<String> referenceIds,

    /// Images the user attached in the composer → NIP-92 `imeta` tags.
    @Default(<MediaBlobEntity>[]) List<MediaBlobEntity> attachments,
  }) = _ShareNoteInput;
}
