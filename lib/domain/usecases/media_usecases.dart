import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/media_repository.dart';
import 'package:uniun/domain/repositories/note_repository.dart';

class UploadMediaInput {
  const UploadMediaInput({
    required this.bytes,
    required this.mime,
    this.filename,
    this.blurhash,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String mime;
  final String? filename;
  final String? blurhash;
  final int? width;
  final int? height;
}

class DownloadMediaInput {
  const DownloadMediaInput({
    required this.sha256,
    required this.url,
    required this.mime,
  });

  final String sha256;
  final String url;
  final String mime;
}

/// Same shape as [UploadMediaInput] — staged to the local cache only.
class SaveLocalMediaInput {
  const SaveLocalMediaInput({
    required this.bytes,
    required this.mime,
    this.filename,
    this.blurhash,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String mime;
  final String? filename;
  final String? blurhash;
  final int? width;
  final int? height;
}

@lazySingleton
class UploadMediaUseCase
    extends UseCase<Either<Failure, MediaBlobEntity>, UploadMediaInput> {
  const UploadMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, MediaBlobEntity>> call(
    UploadMediaInput input, {
    bool cached = false,
  }) =>
      _repo.uploadBytes(
        bytes: input.bytes,
        mime: input.mime,
        filename: input.filename,
        blurhash: input.blurhash,
        width: input.width,
        height: input.height,
      );
}

/// Stage picked media on-device without uploading (draft media). The bytes
/// are uploaded later, when the draft is published.
@lazySingleton
class SaveLocalMediaUseCase
    extends UseCase<Either<Failure, MediaBlobEntity>, SaveLocalMediaInput> {
  const SaveLocalMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, MediaBlobEntity>> call(
    SaveLocalMediaInput input, {
    bool cached = false,
  }) =>
      _repo.saveLocalBytes(
        bytes: input.bytes,
        mime: input.mime,
        filename: input.filename,
        blurhash: input.blurhash,
        width: input.width,
        height: input.height,
      );
}

/// Re-hydrate staged draft-media bytes from the local cache by sha256, e.g. to
/// restore them into the composer for editing or to upload them on publish.
@lazySingleton
class ReadLocalMediaUseCase
    extends UseCase<Either<Failure, Uint8List?>, String> {
  const ReadLocalMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, Uint8List?>> call(String sha256, {bool cached = false}) =>
      _repo.readLocalBytes(sha256);
}

@lazySingleton
class DownloadMediaUseCase
    extends UseCase<Either<Failure, MediaBlobEntity>, DownloadMediaInput> {
  const DownloadMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, MediaBlobEntity>> call(
    DownloadMediaInput input, {
    bool cached = false,
  }) =>
      _repo.downloadBySha(
        sha256: input.sha256,
        url: input.url,
        mime: input.mime,
      );
}

@lazySingleton
class WatchMediaUseCase
    extends StreamUseCase<List<MediaBlobEntity>, MediaFilter?> {
  const WatchMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Stream<List<MediaBlobEntity>> call(MediaFilter? filter) =>
      _repo.watchAll(filter: filter);
}

@lazySingleton
class RemoveLocalMediaUseCase
    extends UseCase<Either<Failure, Unit>, String> {
  const RemoveLocalMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, Unit>> call(String sha256, {bool cached = false}) =>
      _repo.removeLocal(sha256);
}

// ── PublishMediaNoteUseCase ───────────────────────────────────────────────────

class PublishMediaNoteInput {
  const PublishMediaNoteInput({
    required this.note,
    required this.attachments,
  });

  /// Pre-signed note. `note.id`/`note.sig` are the result of signing the
  /// canonical tag layout — which includes the `imeta` tags for these
  /// attachments. See `EventQueueModel.toSerializedRelayMessage` for the
  /// authoritative order.
  final NoteEntity note;

  /// One [MediaBlobEntity] per `imeta` tag on the note. Carries the imeta
  /// fields the queue's serializer needs to reproduce the tag list.
  final List<MediaBlobEntity> attachments;
}

/// Outbound publish path for notes carrying NIP-92 `imeta` tags. Identical
/// flow to a plain `PublishNoteUseCase`, but passes the typed `imeta:` list
/// to the queue so the serializer can emit `imeta` tags in the canonical
/// order. No raw-passthrough.
@lazySingleton
class PublishMediaNoteUseCase
    extends UseCase<Either<Failure, NoteEntity>, PublishMediaNoteInput> {
  const PublishMediaNoteUseCase(this._noteRepo, this._eventQueue);

  final NoteRepository _noteRepo;
  final EventQueueRepository _eventQueue;

  @override
  Future<Either<Failure, NoteEntity>> call(
    PublishMediaNoteInput input, {
    bool cached = false,
  }) async {
    final saveResult = await _noteRepo.saveNote(input.note);
    if (saveResult.isLeft()) return saveResult;

    final enqueueResult = await _eventQueue.enqueueSignedEvent(
      eventId: input.note.id,
      authorPubkey: input.note.authorPubkey,
      sig: input.note.sig,
      kind: 1,
      eTagRefs: input.note.eTagRefs,
      rootEventId: input.note.rootEventId,
      replyToEventId: input.note.replyToEventId,
      pTagRefs: input.note.pTagRefs,
      tTags: input.note.tTags,
      content: input.note.content,
      created: input.note.created,
      embeddedNoteJson: input.note.embeddedNoteJson,
      imeta: input.attachments,
    );
    if (enqueueResult.isLeft()) {
      return Left(enqueueResult.fold(
        (f) => f,
        (_) => const Failure.errorFailure('enqueue failed'),
      ));
    }
    return Right(input.note);
  }
}
