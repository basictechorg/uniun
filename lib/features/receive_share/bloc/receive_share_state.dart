part of 'receive_share_bloc.dart';

@freezed
abstract class ReceiveShareState with _$ReceiveShareState {
  const factory ReceiveShareState({
    /// Loading the destination lists. True until [InitReceiveShare] resolves.
    @Default(true) bool loading,

    /// Reading/compressing/uploading the shared files on init.
    @Default(false) bool ingesting,

    /// Uploading a single file picked via the in-sheet "+" button.
    @Default(false) bool uploading,
    @Default(false) bool submitting,
    @Default(false) bool submitted,
    @Default(false) bool draftSaved,

    /// Active user's pubkey — seeds the composer avatar.
    @Default('') String authorPubkey,

    /// The composed note text (seeded from the shared text).
    @Default('') String content,

    /// Referenced notes picked in the composer → NIP-10 `e` mention tags.
    @Default(<ComposerReference>[]) List<ComposerReference> references,

    /// Uploaded blobs → NIP-92 `imeta` tags on publish.
    @Default(<MediaBlobEntity>[]) List<MediaBlobEntity> attachments,
    @Default(<ChannelEntity>[]) List<ChannelEntity> publicChannels,
    @Default(<PrivateChannelEntity>[]) List<PrivateChannelEntity> privateChannels,
    @Default(<DmConversationEntity>[]) List<DmConversationEntity> dmConversations,
    String? error,
  }) = _ReceiveShareState;
}
