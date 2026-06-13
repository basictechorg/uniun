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

  /// Defaults below are deliberate — legacy rows stored before any of these
  /// fields existed deserialize cleanly instead of throwing a
  /// LateInitializationError on first access. Keep the field type
  /// non-nullable for ergonomic call sites.
  String mime = 'application/octet-stream';
  int sizeBytes = 0;

  int? width;
  int? height;

  String? blurhash;

  /// Original filename as picked on the publisher's device (e.g.
  /// `Q4-report.pdf`). Travels via the NIP-92 `imeta` `name` field. Nullable
  /// because legacy rows / image attachments don't carry one — receivers
  /// then fall back to a mime-derived label.
  String? filename;

  /// Blossom server URLs known to hold this blob. v1 publishes one entry
  /// (our backend); BUD-03 leaves room for fan-out later.
  List<String> serverUrls = [];

  /// Absolute path under getApplicationSupportDirectory()/media/. Null = not
  /// downloaded.
  String? localPath;

  DateTime? downloadedAt;

  /// Last time we saw this sha referenced anywhere — informational, used by
  /// the gallery sort.
  @Index()
  DateTime lastSeenAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// True = GC never deletes the local file even if no note references it.
  @Index()
  bool pinned = false;
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
        filename: filename,
        serverUrls: serverUrls,
        localPath: localPath,
        downloadedAt: downloadedAt,
        lastSeenAt: lastSeenAt,
        pinned: pinned,
      );
}
