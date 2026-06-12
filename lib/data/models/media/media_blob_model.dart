import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_dim.dart';

part 'media_blob_model.g.dart';

/// One row per content-addressed blob the user has either uploaded or seen
/// referenced by a note. [localPath] is null when the bytes have not been
/// downloaded yet — the row is still useful for blurhash preview and the
/// gallery's "not cached" view.
///
/// `sha256` is the only stable key. The (server URL, extension) tuple can
/// drift; the hash does not.
@Collection(ignore: {'copyWith'})
@Name('MediaBlob')
class MediaBlobModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String sha256;

  late String mime;
  late int sizeBytes;

  int? width;
  int? height;

  String? blurhash;

  /// Blossom server URLs known to hold this blob. v1 publishes one entry
  /// (our backend); BUD-03 leaves room for fan-out later.
  late List<String> serverUrls;

  /// Absolute path under getApplicationSupportDirectory()/media/. Null = not
  /// downloaded.
  String? localPath;

  DateTime? downloadedAt;

  /// Last time we saw this sha referenced anywhere — informational, used by
  /// the gallery sort.
  @Index()
  late DateTime lastSeenAt;

  /// True = GC never deletes the local file even if no note references it.
  @Index()
  late bool pinned;
}

extension MediaBlobModelExtension on MediaBlobModel {
  MediaBlobEntity toDomain() => MediaBlobEntity(
        sha256: sha256,
        mime: mime,
        sizeBytes: sizeBytes,
        dim: (width != null && height != null)
            ? MediaDim(width: width!, height: height!)
            : null,
        blurhash: blurhash,
        serverUrls: serverUrls,
        localPath: localPath,
        downloadedAt: downloadedAt,
        lastSeenAt: lastSeenAt,
        pinned: pinned,
      );
}
