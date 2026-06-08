import 'package:freezed_annotation/freezed_annotation.dart';

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
    /// Event id of the note being shared. Resolved by the repository so it
    /// can stamp the original author into the outgoing event's tags.
    required String sourceEventId,
    required ShareDestination destination,

    /// Optional caption typed by the user above the embedded note. The
    /// `nostr:note1...` pointer is appended automatically by the repository.
    @Default('') String comment,
  }) = _ShareNoteInput;
}
