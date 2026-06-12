import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/domain/entities/media/media_dim.dart';

part 'media_blob_entity.freezed.dart';

@freezed
abstract class MediaBlobEntity with _$MediaBlobEntity {
  const factory MediaBlobEntity({
    required String sha256,
    required String mime,
    required int sizeBytes,
    MediaDim? dim,
    String? blurhash,
    required List<String> serverUrls,
    String? localPath,
    DateTime? downloadedAt,
    required DateTime lastSeenAt,
    required bool pinned,
  }) = _MediaBlobEntity;
}
