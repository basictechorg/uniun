part of 'receive_share_bloc.dart';

@freezed
abstract class ReceiveShareState with _$ReceiveShareState {
  const factory ReceiveShareState({
    /// Loading the destination lists. True until [InitReceiveShare] resolves.
    @Default(true) bool loading,

    /// Reading/compressing the shared files on init (no upload — that's
    /// deferred to submit).
    @Default(false) bool ingesting,
    @Default(false) bool submitting,
    @Default(false) bool submitted,
    @Default(false) bool draftSaved,

    /// Active user's pubkey — seeds the composer avatar.
    @Default('') String authorPubkey,

    /// The composed note text (seeded from the shared text).
    @Default('') String content,

    /// Referenced notes picked in the composer → NIP-10 `e` mention tags.
    @Default(<ComposerReference>[]) List<ComposerReference> references,

    /// Picked-but-not-yet-uploaded media → uploaded to Blossom on submit, then
    /// emitted as NIP-92 `imeta` tags.
    @Default(<PickedMedia>[]) List<PickedMedia> pending,
    @Default(<GroupEntity>[]) List<GroupEntity> publicGroups,
    @Default(<PrivateGroupEntity>[]) List<PrivateGroupEntity> privateGroups,
    @Default(<DmConversationEntity>[]) List<DmConversationEntity> dmConversations,
    String? error,
  }) = _ReceiveShareState;
}
