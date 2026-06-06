part of 'share_sheet_bloc.dart';

@freezed
sealed class ShareSheetEvent with _$ShareSheetEvent {
  const factory ShareSheetEvent.loadDestinations() = LoadDestinations;
  const factory ShareSheetEvent.commentChanged(String value) = CommentChanged;
  const factory ShareSheetEvent.submit({
    required String sourceEventId,
    required ShareDestination destination,
  }) = SubmitShare;
}
