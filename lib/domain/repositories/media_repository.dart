import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';

abstract class MediaRepository {
  /// Upload raw bytes. Computes sha256, HEAD-dedupes against the server,
  /// PUTs only if missing, caches bytes locally, upserts the manifest row.
  /// Callers in the data/presentation layer read [File] bytes themselves
  /// before calling — dart:io stays out of the domain.
  ///
  /// [blurhash], [width], [height] are caller-provided (computed in a
  /// presentation-layer isolate via `compute()` to avoid jank). Repository
  /// does not decode the image itself.
  Future<Either<Failure, MediaBlobEntity>> uploadBytes({
    required Uint8List bytes,
    required String mime,
    String? filename,
    String? blurhash,
    int? width,
    int? height,
  });

  /// User-initiated download. Fetches bytes from the first reachable server
  /// in [MediaBlobEntity.serverUrls], writes to the local cache, populates
  /// [MediaBlobEntity.localPath].
  Future<Either<Failure, MediaBlobEntity>> downloadBySha(String sha256);

  Future<Either<Failure, MediaBlobEntity>> getBySha(String sha256);

  Stream<List<MediaBlobEntity>> watchAll({MediaFilter? filter});

  Future<Either<Failure, Unit>> pin(String sha256);
  Future<Either<Failure, Unit>> unpin(String sha256);

  /// Delete the local file only. Manifest row stays so the user can
  /// re-download later from the server.
  Future<Either<Failure, Unit>> removeLocal(String sha256);

  /// Link a note's eventId to a blob sha. Called from inbound handlers and
  /// the outbound publish path. Idempotent.
  Future<Either<Failure, Unit>> linkNoteRef({
    required String sha256,
    required String noteEventId,
  });

  /// Notes that reference a given blob — used by the detail page and the GC
  /// pass.
  Future<Either<Failure, List<String>>> getReferencingNoteIds(String sha256);

  /// Blobs referenced by a given note — used by NoteCard to render
  /// attachments inline.
  Future<Either<Failure, List<MediaBlobEntity>>> getBlobsForNote(
    String noteEventId,
  );
}
