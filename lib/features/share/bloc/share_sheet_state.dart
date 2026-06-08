part of 'share_sheet_bloc.dart';

@freezed
abstract class ShareSheetState with _$ShareSheetState {
  const factory ShareSheetState({
    @Default(false) bool loading,
    @Default(false) bool submitting,
    @Default(false) bool submitted,
    @Default('') String comment,
    @Default(<ChannelEntity>[]) List<ChannelEntity> publicChannels,
    @Default(<PrivateChannelEntity>[]) List<PrivateChannelEntity> privateChannels,
    @Default(<DmConversationEntity>[]) List<DmConversationEntity> dmConversations,
    String? error,
  }) = _ShareSheetState;
}
