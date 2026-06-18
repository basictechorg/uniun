part of 'share_sheet_bloc.dart';

@freezed
abstract class ShareSheetState with _$ShareSheetState {
  const factory ShareSheetState({
    @Default(false) bool loading,
    @Default(false) bool submitting,
    @Default(false) bool submitted,
    @Default(false) bool uploading,

    /// Active user's pubkey — seeds the composer avatar.
    @Default('') String authorPubkey,

    /// The user's composed note text published alongside the embed.
    @Default('') String content,

    /// Referenced notes selected in the composer → `e` mention tags.
    @Default(<ComposerReference>[]) List<ComposerReference> references,

    /// Uploaded images attached in the composer → `imeta` tags.
    @Default(<MediaBlobEntity>[]) List<MediaBlobEntity> attachments,
    @Default(<ChannelEntity>[]) List<ChannelEntity> publicChannels,
    @Default(<PrivateChannelEntity>[]) List<PrivateChannelEntity> privateChannels,
    @Default(<DmConversationEntity>[]) List<DmConversationEntity> dmConversations,
    String? error,
  }) = _ShareSheetState;
}
