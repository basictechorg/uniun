import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';

enum MediaGalleryStatus { initial, loading, loaded, error }

class MediaGalleryState {
  const MediaGalleryState({
    this.status = MediaGalleryStatus.initial,
    this.filter = const MediaFilter(),
    this.blobs = const [],
    this.busyShas = const {},
    this.errorMessage,
  });

  final MediaGalleryStatus status;
  final MediaFilter filter;
  final List<MediaBlobEntity> blobs;

  /// sha256s with an in-flight action (download / pin toggle / remove). The
  /// tile renders a spinner over the affordance while present.
  final Set<String> busyShas;

  final String? errorMessage;

  MediaGalleryState copyWith({
    MediaGalleryStatus? status,
    MediaFilter? filter,
    List<MediaBlobEntity>? blobs,
    Set<String>? busyShas,
    String? errorMessage,
  }) {
    return MediaGalleryState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      blobs: blobs ?? this.blobs,
      busyShas: busyShas ?? this.busyShas,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
