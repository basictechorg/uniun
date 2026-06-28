part of 'share_sheet_bloc.dart';

@freezed
abstract class ShareSheetState with _$ShareSheetState {
  const factory ShareSheetState({
    @Default(false) bool loading,
    @Default(false) bool submitting,
    @Default(false) bool submitted,

    /// Active user's pubkey — seeds the composer avatar.
    @Default('') String authorPubkey,

    /// The user's composed note text published alongside the embed.
    @Default('') String content,

    /// Referenced notes selected in the composer → `e` mention tags.
    @Default(<ComposerReference>[]) List<ComposerReference> references,

    /// Picked-but-not-yet-uploaded media → uploaded to Blossom on submit, then
    /// emitted as `imeta` tags.
    @Default(<PickedMedia>[]) List<PickedMedia> pending,
    @Default(<GroupEntity>[]) List<GroupEntity> publicGroups,
    @Default(<PrivateGroupEntity>[]) List<PrivateGroupEntity> privateGroups,
    @Default(<DmConversationEntity>[]) List<DmConversationEntity> dmConversations,

    /// The original note being shared, resolved for the "Quoting" preview card.
    /// Null while loading or if it can't be resolved (the card is then hidden).
    NoteEntity? quotedNote,

    /// Destination highlighted by the user; the bottom Share button publishes
    /// it. Null until the user picks one (button stays disabled).
    ShareDestination? selectedDestination,
    String? error,
  }) = _ShareSheetState;
}
