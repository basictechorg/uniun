import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';

enum MediaGalleryStatus { initial, loading, loaded, error }

class MediaGalleryState {
  const MediaGalleryState({
    this.status = MediaGalleryStatus.initial,
    this.filter = const MediaFilter(),
    this.blobs = const [],
    this.busyShas = const {},
    this.selectedShas = const {},
    this.errorMessage,
  });

  final MediaGalleryStatus status;
  final MediaFilter filter;
  final List<MediaBlobEntity> blobs;

  /// sha256s with an in-flight action (download / pin toggle / remove). The
  /// tile renders a spinner over the affordance while present.
  final Set<String> busyShas;

  /// Multi-selected sha256s. Non-empty = gallery is in selection mode.
  final Set<String> selectedShas;

  final String? errorMessage;

  bool get isSelecting => selectedShas.isNotEmpty;

  MediaGalleryState copyWith({
    MediaGalleryStatus? status,
    MediaFilter? filter,
    List<MediaBlobEntity>? blobs,
    Set<String>? busyShas,
    Set<String>? selectedShas,
    String? errorMessage,
  }) {
    return MediaGalleryState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      blobs: blobs ?? this.blobs,
      busyShas: busyShas ?? this.busyShas,
      selectedShas: selectedShas ?? this.selectedShas,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
