import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';

abstract class MediaRepository {
  /// Upload raw bytes. Computes sha256, HEAD-dedupes against the server,
  /// PUTs only if missing, caches bytes locally, and writes a
  /// [MediaCacheModel] row. The returned [MediaBlobEntity] carries the
  /// imeta metadata + the local path the caller can render immediately.
  ///
  /// dart:io stays out of the domain — the picker reads bytes before
  /// invoking the use case.
  ///
  /// [blurhash], [width], [height] are caller-provided (computed in a
  /// presentation-layer isolate via `compute()` to avoid jank).
  Future<Either<Failure, MediaBlobEntity>> uploadBytes({
    required Uint8List bytes,
    required String mime,
    String? filename,
    String? blurhash,
    int? width,
    int? height,
  });

  /// User-initiated download. Fetches bytes from a known URL (passed in by
  /// the caller — looked up from the note's `imeta` attachments), writes to
  /// the local cache, populates [MediaCacheModel].
  Future<Either<Failure, MediaBlobEntity>> downloadBySha({
    required String sha256,
    required String url,
    required String mime,
  });

  /// Look up the cache entry for a single sha. Returns `null` inside the
  /// Right when the blob isn't on disk.
  Future<Either<Failure, MediaBlobEntity?>> getCachedBySha(String sha256);

  /// Watches the union of (notes that have attachments) and
  /// (MediaCacheModel rows). Output is deduped by sha256; rows with no
  /// local cache are hidden by default — gallery shows files on disk only.
  Stream<List<MediaBlobEntity>> watchAll({MediaFilter? filter});

  /// Delete the local file + the cache row. The note's `imeta` is
  /// untouched, so the card reverts to "download" the next time it renders.
  Future<Either<Failure, Unit>> removeLocal(String sha256);
}
