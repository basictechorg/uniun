part of 'receive_share_bloc.dart';

@freezed
sealed class ReceiveShareEvent with _$ReceiveShareEvent {
  /// Seed the sheet from an inbound OS share: pre-fill text + ingest media.
  const factory ReceiveShareEvent.init(SharedIncoming incoming) =
      InitReceiveShare;

  /// The user edited the composed note text.
  const factory ReceiveShareEvent.contentChanged(String value) =
      ReceiveContentChanged;

  /// Upload + attach an additional picked file (the in-sheet "+" picker).
  const factory ReceiveShareEvent.attachMedia({
    required Uint8List bytes,
    required String mime,
    String? filename,
    int? width,
    int? height,
  }) = AttachReceiveMedia;

  /// Remove a previously-attached blob by its sha256.
  const factory ReceiveShareEvent.removeMedia(String sha256) =
      RemoveReceiveMedia;

  /// Reference picker returned its full selection (replaces current refs).
  const factory ReceiveShareEvent.setReferences(
      List<ComposerReference> references) = SetReceiveReferences;

  /// Remove a single referenced note by its event id.
  const factory ReceiveShareEvent.removeReference(String id) =
      RemoveReceiveReference;

  /// Save the composed text as a local draft (text-only).
  const factory ReceiveShareEvent.saveToDraft() = SaveReceiveDraft;

  /// Publish the composed note to the chosen destination (feed / channel /
  /// private channel / DM).
  const factory ReceiveShareEvent.submit(ShareDestination destination) =
      SubmitReceiveShare;
}
