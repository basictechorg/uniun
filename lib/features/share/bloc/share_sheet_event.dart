part of 'share_sheet_bloc.dart';

@freezed
sealed class ShareSheetEvent with _$ShareSheetEvent {
  const factory ShareSheetEvent.loadDestinations() = LoadDestinations;

  /// The user's composed note text changed.
  const factory ShareSheetEvent.contentChanged(String value) = ContentChanged;

  /// Reference picker returned its full selection (replaces current refs).
  const factory ShareSheetEvent.setReferences(
      List<ComposerReference> references) = SetReferences;

  /// Remove a single referenced note by its event id.
  const factory ShareSheetEvent.removeReference(String id) = RemoveReference;

  /// Upload + attach a picked image (Blossom).
  const factory ShareSheetEvent.attachMedia({
    required Uint8List bytes,
    required String mime,
    String? filename,
    int? width,
    int? height,
  }) = AttachMedia;

  /// Remove a previously-attached image by its sha256.
  const factory ShareSheetEvent.removeMedia(String sha256) = RemoveMedia;

  const factory ShareSheetEvent.submit({
    required String sourceEventId,
    required ShareDestination destination,
  }) = SubmitShare;
}
