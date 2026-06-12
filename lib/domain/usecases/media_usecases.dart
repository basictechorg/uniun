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

class LinkNoteMediaRefInput {
  const LinkNoteMediaRefInput({required this.sha256, required this.noteEventId});
  final String sha256;
  final String noteEventId;
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

@lazySingleton
class DownloadMediaUseCase
    extends UseCase<Either<Failure, MediaBlobEntity>, String> {
  const DownloadMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, MediaBlobEntity>> call(
    String sha256, {
    bool cached = false,
  }) =>
      _repo.downloadBySha(sha256);
}

@lazySingleton
class GetMediaUseCase
    extends UseCase<Either<Failure, MediaBlobEntity>, String> {
  const GetMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, MediaBlobEntity>> call(
    String sha256, {
    bool cached = false,
  }) =>
      _repo.getBySha(sha256);
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
class PinMediaUseCase extends UseCase<Either<Failure, Unit>, String> {
  const PinMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, Unit>> call(String sha256, {bool cached = false}) =>
      _repo.pin(sha256);
}

@lazySingleton
class UnpinMediaUseCase extends UseCase<Either<Failure, Unit>, String> {
  const UnpinMediaUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, Unit>> call(String sha256, {bool cached = false}) =>
      _repo.unpin(sha256);
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

@lazySingleton
class LinkNoteMediaRefUseCase
    extends UseCase<Either<Failure, Unit>, LinkNoteMediaRefInput> {
  const LinkNoteMediaRefUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, Unit>> call(
    LinkNoteMediaRefInput input, {
    bool cached = false,
  }) =>
      _repo.linkNoteRef(
        sha256: input.sha256,
        noteEventId: input.noteEventId,
      );
}

@lazySingleton
class GetBlobsForNoteUseCase
    extends UseCase<Either<Failure, List<MediaBlobEntity>>, String> {
  const GetBlobsForNoteUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, List<MediaBlobEntity>>> call(
    String noteEventId, {
    bool cached = false,
  }) =>
      _repo.getBlobsForNote(noteEventId);
}

@lazySingleton
class GetReferencingNoteIdsUseCase
    extends UseCase<Either<Failure, List<String>>, String> {
  const GetReferencingNoteIdsUseCase(this._repo);
  final MediaRepository _repo;

  @override
  Future<Either<Failure, List<String>>> call(
    String sha256, {
    bool cached = false,
  }) =>
      _repo.getReferencingNoteIds(sha256);
}

// ── PublishMediaNoteUseCase ───────────────────────────────────────────────────

class PublishMediaNoteInput {
  const PublishMediaNoteInput({
    required this.note,
    required this.fullSignedJson,
    required this.attachedShas,
  });

  final NoteEntity note;

  /// Full signed event JSON as the relay should receive it — caller built
  /// the tag array (including imeta) and called `Event.from(...)` to sign.
  /// We store this in [EventQueueModel.content] and use the rawPassthrough
  /// path so the wire bytes hash back to the signed id.
  final String fullSignedJson;

  /// sha256s referenced by this note. Each gets a [NoteMediaRefModel] row
  /// so the gallery + GC see the linkage from day one (the gateway inbound
  /// handler would do this too on receive, but we are the sender).
  final List<String> attachedShas;
}

/// Outbound publish path for notes that carry NIP-92 `imeta` tags. Mirrors
/// [PublishNoteUseCase] but signals raw-passthrough to the outbound pump so
/// the imeta tag order survives serialization.
@lazySingleton
class PublishMediaNoteUseCase
    extends UseCase<Either<Failure, NoteEntity>, PublishMediaNoteInput> {
  const PublishMediaNoteUseCase(
    this._noteRepo,
    this._eventQueue,
    this._mediaRepo,
  );

  final NoteRepository _noteRepo;
  final EventQueueRepository _eventQueue;
  final MediaRepository _mediaRepo;

  @override
  Future<Either<Failure, NoteEntity>> call(
    PublishMediaNoteInput input, {
    bool cached = false,
  }) async {
    final saveResult = await _noteRepo.saveNote(input.note);
    if (saveResult.isLeft()) return saveResult;

    for (final sha in input.attachedShas) {
      await _mediaRepo.linkNoteRef(sha256: sha, noteEventId: input.note.id);
    }

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
      content: input.fullSignedJson,
      created: input.note.created,
      quoteEventId: input.note.quoteEventId,
      rawPassthrough: true,
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
