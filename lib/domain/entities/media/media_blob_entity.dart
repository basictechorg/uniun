import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/domain/entities/media/media_dim.dart';

part 'media_blob_entity.freezed.dart';

/// One media attachment as the UI sees it. Combines the NIP-92 imeta
/// metadata (always present) with the local cache state (null when the
/// bytes aren't on disk).
@freezed
abstract class MediaBlobEntity with _$MediaBlobEntity {
  const factory MediaBlobEntity({
    required String sha256,
    required String mime,
    required int sizeBytes,
    MediaDim? dim,
    String? blurhash,
    String? filename,
    @Default([]) List<String> serverUrls,
    String? localPath,
    DateTime? downloadedAt,
  }) = _MediaBlobEntity;
}
