import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/blossom_client.dart';
import 'package:uniun/data/datasources/media_cache_data_source.dart';
import 'package:uniun/data/models/media/media_blob_model.dart';
import 'package:uniun/data/models/media/note_media_ref_model.dart';
import 'package:uniun/data/models/user_server_list_model.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';
import 'package:uniun/domain/repositories/media_repository.dart';
import 'package:uniun/domain/repositories/user_server_list_repository.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

@Injectable(as: MediaRepository)
class MediaRepositoryImpl extends MediaRepository {
  MediaRepositoryImpl({
    required this.isar,
    required BlossomClient blossom,
    required MediaCacheDataSource cache,
    required UserServerListRepository serverList,
    required GetActiveUserKeysUseCase getActiveUserKeys,
  })  : _blossom = blossom,
        _cache = cache,
        _serverList = serverList,
        _getActiveUserKeys = getActiveUserKeys;

  final Isar isar;
  final BlossomClient _blossom;
  final MediaCacheDataSource _cache;
  final UserServerListRepository _serverList;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  @override
  Future<Either<Failure, MediaBlobEntity>> uploadBytes({
    required Uint8List bytes,
    required String mime,
    String? filename,
    String? blurhash,
    int? width,
    int? height,
  }) async {
    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);
      if (keys == null) {
        return const Left(Failure.failure('No active user'));
      }

      final sha256 = crypto.sha256.convert(bytes).toString();
      final ext = _extFromMime(mime, filename);

      final serversResult = await _serverList.getServers();
      final servers = serversResult.fold((_) => <String>[], (s) => s);
      if (servers.isEmpty) {
        return const Left(Failure.failure('No Blossom server configured'));
      }
      final primary = servers.first;

      var serverHas = false;
      try {
        serverHas = await _blossom.head(primary, sha256, ext: ext);
      } catch (_) {
        serverHas = false;
      }

      // Build the public URL from our HTTP base. Khatru's `descriptor.url`
      // uses the relay's `wss://` URL — unusable for HTTP fetch.
      final String publicUrl =
          '$primary/$sha256${ext != null ? '.$ext' : ''}';
      if (!serverHas) {
        await _blossom.upload(
          serverUrl: primary,
          bytes: bytes,
          mime: mime,
          sha256: sha256,
          keys: keys,
        );
      }

      await _cache.write(sha256, ext, bytes);

      final existingRow = await isar.userServerListModels.get(0);
      if (existingRow == null || existingRow.serverUrls.isEmpty) {
        await _serverList.setServers([primary]);
      }

      final localFile = await _cache.fileFor(sha256, ext);
      final entity = await _upsertManifest(
        sha256: sha256,
        mime: mime,
        sizeBytes: bytes.length,
        width: width,
        height: height,
        blurhash: blurhash,
        filename: filename,
        addServerUrl: publicUrl,
        localPath: localFile.path,
        downloadedAt: DateTime.now(),
      );
      return Right(entity);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MediaBlobEntity>> downloadBySha(String sha256) async {
    try {
      final row = await isar.mediaBlobModels
          .filter()
          .sha256EqualTo(sha256)
          .findFirst();
      if (row == null) {
        return const Left(Failure.notFoundFailure('Blob not in manifest'));
      }

      final ext = _extFromMime(row.mime, null);

      // Already cached — short-circuit.
      if (await _cache.exists(sha256, ext)) {
        final f = await _cache.read(sha256, ext);
        if (f != null) {
          await isar.writeTxn(() async {
            row.localPath = f.path;
            row.downloadedAt ??= DateTime.now();
            await isar.mediaBlobModels.put(row);
          });
          return Right(row.toDomain());
        }
      }

      final servers = row.serverUrls.isNotEmpty
          ? row.serverUrls
          : (await _serverList.getServers()).fold((_) => <String>[], (s) => s);

      Uint8List? bytes;
      String? successUrl;
      for (final base in servers) {
        try {
          // Use the full stored URL directly — it already has the correct
          // extension for any file type (png, mp4, pdf, etc.).
          bytes = await _blossom.downloadFromUrl(base);
          successUrl = base;
          break;
        } catch (_) {
          // Try the next server.
        }
      }
      if (bytes == null) {
        return const Left(Failure.failure('All servers failed'));
      }

      await _cache.write(sha256, ext, bytes);
      final localFile = await _cache.fileFor(sha256, ext);

      final entity = await _upsertManifest(
        sha256: sha256,
        mime: row.mime,
        sizeBytes: bytes.length,
        width: row.width,
        height: row.height,
        blurhash: row.blurhash,
        addServerUrl: successUrl,
        localPath: localFile.path,
        downloadedAt: DateTime.now(),
      );
      return Right(entity);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MediaBlobEntity>> getBySha(String sha256) async {
    try {
      final row = await isar.mediaBlobModels
          .filter()
          .sha256EqualTo(sha256)
          .findFirst();
      if (row == null) {
        return const Left(Failure.notFoundFailure('Blob not found'));
      }
      return Right(row.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Stream<List<MediaBlobEntity>> watchAll({MediaFilter? filter}) {
    final f = filter ?? const MediaFilter();
    return isar.mediaBlobModels
        .where()
        .sortByLastSeenAtDesc()
        .watch(fireImmediately: true)
        .map((rows) => rows
            .where((r) => _matches(r, f))
            .map((r) => r.toDomain())
            .toList());
  }

  @override
  Future<Either<Failure, Unit>> pin(String sha256) => _setPinned(sha256, true);

  @override
  Future<Either<Failure, Unit>> unpin(String sha256) =>
      _setPinned(sha256, false);

  Future<Either<Failure, Unit>> _setPinned(String sha256, bool value) async {
    try {
      await isar.writeTxn(() async {
        final row = await isar.mediaBlobModels
            .filter()
            .sha256EqualTo(sha256)
            .findFirst();
        if (row == null) return;
        row.pinned = value;
        await isar.mediaBlobModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeLocal(String sha256) async {
    try {
      final row = await isar.mediaBlobModels
          .filter()
          .sha256EqualTo(sha256)
          .findFirst();
      if (row == null) return const Right(unit);
      await _cache.delete(sha256, _extFromMime(row.mime, null));
      await isar.writeTxn(() async {
        row.localPath = null;
        row.downloadedAt = null;
        await isar.mediaBlobModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> linkNoteRef({
    required String sha256,
    required String noteEventId,
  }) async {
    try {
      await isar.writeTxn(() async {
        final existing = await isar.noteMediaRefModels
            .filter()
            .noteEventIdEqualTo(noteEventId)
            .mediaSha256EqualTo(sha256)
            .findFirst();
        if (existing != null) return;
        final row = NoteMediaRefModel()
          ..noteEventId = noteEventId
          ..mediaSha256 = sha256;
        await isar.noteMediaRefModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getReferencingNoteIds(
    String sha256,
  ) async {
    try {
      final rows = await isar.noteMediaRefModels
          .filter()
          .mediaSha256EqualTo(sha256)
          .findAll();
      return Right(rows.map((r) => r.noteEventId).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MediaBlobEntity>>> getBlobsForNote(
    String noteEventId,
  ) async {
    try {
      final refs = await isar.noteMediaRefModels
          .filter()
          .noteEventIdEqualTo(noteEventId)
          .findAll();
      if (refs.isEmpty) return const Right([]);
      final shas = refs.map((r) => r.mediaSha256).toSet().toList();
      final blobs = await isar.mediaBlobModels
          .filter()
          .anyOf(shas, (q, sha) => q.sha256EqualTo(sha))
          .findAll();
      return Right(blobs.map((b) => b.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────

  /// Upsert by sha256. Merges incoming server URL into [serverUrls] without
  /// duplicates. Preserves [pinned] across writes.
  Future<MediaBlobEntity> _upsertManifest({
    required String sha256,
    required String mime,
    required int sizeBytes,
    int? width,
    int? height,
    String? blurhash,
    String? filename,
    String? addServerUrl,
    String? localPath,
    DateTime? downloadedAt,
  }) async {
    late MediaBlobModel saved;
    await isar.writeTxn(() async {
      final existing = await isar.mediaBlobModels
          .filter()
          .sha256EqualTo(sha256)
          .findFirst();
      final row = existing ?? MediaBlobModel();
      row.sha256 = sha256;
      row.mime = mime;
      row.sizeBytes = sizeBytes;
      row.width = width ?? row.width;
      row.height = height ?? row.height;
      row.blurhash = blurhash ?? row.blurhash;
      row.filename = filename ?? row.filename;
      final urls = <String>{...row.serverUrls};
      if (addServerUrl != null) urls.add(addServerUrl);
      row.serverUrls = urls.toList();
      if (localPath != null) row.localPath = localPath;
      if (downloadedAt != null) row.downloadedAt = downloadedAt;
      row.lastSeenAt = DateTime.now();
      row.pinned = existing?.pinned ?? false;
      await isar.mediaBlobModels.put(row);
      saved = row;
    });
    return saved.toDomain();
  }

  bool _matches(MediaBlobModel r, MediaFilter f) {
    // Gallery only surfaces blobs the user actually has on-device — either
    // uploaded by them or explicitly downloaded. Inbound-only manifest rows
    // (localPath == null) stay hidden until the user pulls the bytes.
    if (r.localPath == null) return false;
    if (f.pinnedOnly && !r.pinned) return false;
    switch (f.cache) {
      case MediaCacheFilter.cached:
        if (r.localPath == null) return false;
        break;
      case MediaCacheFilter.notCached:
        if (r.localPath != null) return false;
        break;
      case MediaCacheFilter.any:
        break;
    }
    switch (f.kind) {
      case MediaKindFilter.all:
        return true;
      case MediaKindFilter.image:
        return r.mime.startsWith('image/');
      case MediaKindFilter.video:
        return r.mime.startsWith('video/');
      case MediaKindFilter.audio:
        return r.mime.startsWith('audio/');
      case MediaKindFilter.file:
        return !r.mime.startsWith('image/') &&
            !r.mime.startsWith('video/') &&
            !r.mime.startsWith('audio/');
    }
  }

  /// Best-effort extension from mime; falls back to filename suffix.
  String? _extFromMime(String mime, String? filename) {
    final fromMime = _mimeToExt[mime.toLowerCase()];
    if (fromMime != null) return fromMime;
    if (filename != null) {
      final ext = p.extension(filename);
      if (ext.isNotEmpty) return ext.replaceFirst('.', '');
    }
    return null;
  }

  static const Map<String, String> _mimeToExt = {
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'image/avif': 'avif',
    'video/mp4': 'mp4',
    'video/webm': 'webm',
    'video/quicktime': 'mov',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
    'audio/ogg': 'ogg',
    'audio/wav': 'wav',
    'application/pdf': 'pdf',
    'text/plain': 'txt',
    'application/json': 'json',
  };
}

