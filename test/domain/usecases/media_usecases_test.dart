import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/media_repository.dart';
import 'package:uniun/domain/repositories/note_repository.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MRepo extends Mock implements MediaRepository {}

class _MNoteRepo extends Mock implements NoteRepository {}

class _MEventQueue extends Mock implements EventQueueRepository {}

/// Covers: every media use case — parameter passthrough to the repository,
/// error propagation from Left(Failure), stream re-emission for the watch
/// use case, and PublishMediaNoteUseCase's two-step (save → enqueue) sequence
/// with failure short-circuit on each step.
void main() {
  setUpAll(() {
    registerFallbackValue(aNote());
    registerFallbackValue(<MediaBlobEntity>[]);
    registerFallbackValue(Uint8List(0));
  });

  late _MRepo repo;
  late _MNoteRepo noteRepo;
  late _MEventQueue queue;

  setUp(() {
    repo = _MRepo();
    noteRepo = _MNoteRepo();
    queue = _MEventQueue();
  });

  // ── UploadMediaUseCase ────────────────────────────────────────────────────

  group('UploadMediaUseCase', () {
    test('forwards every field to repo.uploadBytes', () async {
      when(() => repo.uploadBytes(
            bytes: any(named: 'bytes'),
            mime: any(named: 'mime'),
            filename: any(named: 'filename'),
            blurhash: any(named: 'blurhash'),
            width: any(named: 'width'),
            height: any(named: 'height'),
          )).thenAnswer((_) async => Right(aMediaBlob()));

      final input = UploadMediaInput(
        bytes: Uint8List.fromList([1, 2, 3]),
        mime: 'image/png',
        filename: 'photo.png',
        blurhash: 'BH',
        width: 100,
        height: 80,
      );
      final res = await UploadMediaUseCase(repo).call(input);
      expect(res.isRight(), isTrue);
      verify(() => repo.uploadBytes(
            bytes: input.bytes,
            mime: 'image/png',
            filename: 'photo.png',
            blurhash: 'BH',
            width: 100,
            height: 80,
          )).called(1);
    });

    test('propagates Left(Failure) from the repo', () async {
      when(() => repo.uploadBytes(
            bytes: any(named: 'bytes'),
            mime: any(named: 'mime'),
            filename: any(named: 'filename'),
            blurhash: any(named: 'blurhash'),
            width: any(named: 'width'),
            height: any(named: 'height'),
          )).thenAnswer(
        (_) async => const Left(Failure.errorFailure('boom')),
      );
      final res = await UploadMediaUseCase(repo).call(
        UploadMediaInput(bytes: Uint8List(0), mime: 'image/png'),
      );
      expect(res, const Left(Failure.errorFailure('boom')));
    });
  });

  // ── SaveLocalMediaUseCase ─────────────────────────────────────────────────

  group('SaveLocalMediaUseCase', () {
    test('forwards to repo.saveLocalBytes', () async {
      when(() => repo.saveLocalBytes(
            bytes: any(named: 'bytes'),
            mime: any(named: 'mime'),
            filename: any(named: 'filename'),
            blurhash: any(named: 'blurhash'),
            width: any(named: 'width'),
            height: any(named: 'height'),
          )).thenAnswer((_) async => Right(aMediaBlob()));
      final res = await SaveLocalMediaUseCase(repo).call(
        SaveLocalMediaInput(bytes: Uint8List(0), mime: 'image/png'),
      );
      expect(res.isRight(), isTrue);
      verify(() => repo.saveLocalBytes(
            bytes: any(named: 'bytes'),
            mime: 'image/png',
            filename: null,
            blurhash: null,
            width: null,
            height: null,
          )).called(1);
    });

    test('propagates Left(Failure)', () async {
      when(() => repo.saveLocalBytes(
            bytes: any(named: 'bytes'),
            mime: any(named: 'mime'),
            filename: any(named: 'filename'),
            blurhash: any(named: 'blurhash'),
            width: any(named: 'width'),
            height: any(named: 'height'),
          )).thenAnswer(
        (_) async => const Left(Failure.failure('disk full')),
      );
      final res = await SaveLocalMediaUseCase(repo).call(
        SaveLocalMediaInput(bytes: Uint8List(0), mime: 'image/png'),
      );
      expect(res.isLeft(), isTrue);
    });
  });

  // ── ReadLocalMediaUseCase ─────────────────────────────────────────────────

  group('ReadLocalMediaUseCase', () {
    test('forwards sha to repo.readLocalBytes and returns bytes', () async {
      when(() => repo.readLocalBytes('abc')).thenAnswer(
        (_) async => Right(Uint8List.fromList([1, 2, 3])),
      );
      final res = await ReadLocalMediaUseCase(repo).call('abc');
      expect(res.isRight(), isTrue);
      expect(res.getOrElse(() => null), Uint8List.fromList([1, 2, 3]));
    });

    test('surfaces Right(null) for a missing local file', () async {
      when(() => repo.readLocalBytes('abc')).thenAnswer(
        (_) async => const Right(null),
      );
      final res = await ReadLocalMediaUseCase(repo).call('abc');
      expect(res, const Right<Failure, Uint8List?>(null));
    });

    test('propagates Left(Failure)', () async {
      when(() => repo.readLocalBytes(any())).thenAnswer(
        (_) async => const Left(Failure.errorFailure('io')),
      );
      final res = await ReadLocalMediaUseCase(repo).call('abc');
      expect(res.isLeft(), isTrue);
    });
  });

  // ── DownloadMediaUseCase ──────────────────────────────────────────────────

  group('DownloadMediaUseCase', () {
    test('forwards every field to repo.downloadBySha', () async {
      when(() => repo.downloadBySha(
            sha256: any(named: 'sha256'),
            url: any(named: 'url'),
            mime: any(named: 'mime'),
          )).thenAnswer((_) async => Right(aMediaBlob()));
      final res = await DownloadMediaUseCase(repo).call(
        const DownloadMediaInput(
          sha256: 'sha',
          url: 'https://s/sha.jpg',
          mime: 'image/jpeg',
        ),
      );
      expect(res.isRight(), isTrue);
      verify(() => repo.downloadBySha(
            sha256: 'sha',
            url: 'https://s/sha.jpg',
            mime: 'image/jpeg',
          )).called(1);
    });

    test('propagates Left(Failure)', () async {
      when(() => repo.downloadBySha(
            sha256: any(named: 'sha256'),
            url: any(named: 'url'),
            mime: any(named: 'mime'),
          )).thenAnswer(
        (_) async => const Left(Failure.errorFailure('404')),
      );
      final res = await DownloadMediaUseCase(repo).call(
        const DownloadMediaInput(
          sha256: 'sha',
          url: 'https://s/sha.jpg',
          mime: 'image/jpeg',
        ),
      );
      expect(res.isLeft(), isTrue);
    });
  });

  // ── WatchMediaUseCase ─────────────────────────────────────────────────────

  group('WatchMediaUseCase', () {
    test('forwards filter to repo.watchAll and re-emits every value',
        () async {
      final ctrl = StreamController<List<MediaBlobEntity>>();
      when(() => repo.watchAll(
              filter: const MediaFilter(kind: MediaKindFilter.image)))
          .thenAnswer((_) => ctrl.stream);

      final emissions = <List<MediaBlobEntity>>[];
      final sub = WatchMediaUseCase(repo)
          .call(const MediaFilter(kind: MediaKindFilter.image))
          .listen(emissions.add);

      ctrl.add([aMediaBlob(sha256: 'a')]);
      await Future.delayed(Duration.zero);
      ctrl.add([aMediaBlob(sha256: 'a'), aMediaBlob(sha256: 'b')]);
      await Future.delayed(Duration.zero);
      await sub.cancel();
      await ctrl.close();

      expect(emissions, hasLength(2));
      expect(emissions.last.map((b) => b.sha256).toList(), ['a', 'b']);
    });

    test('passes null filter through to the repo', () {
      final ctrl = StreamController<List<MediaBlobEntity>>();
      when(() => repo.watchAll(filter: null)).thenAnswer((_) => ctrl.stream);
      WatchMediaUseCase(repo).call(null).listen((_) {}).cancel();
      verify(() => repo.watchAll(filter: null)).called(1);
      ctrl.close();
    });
  });

  // ── RemoveLocalMediaUseCase ───────────────────────────────────────────────

  group('RemoveLocalMediaUseCase', () {
    test('forwards sha to repo.removeLocal', () async {
      when(() => repo.removeLocal('abc'))
          .thenAnswer((_) async => const Right(unit));
      final res = await RemoveLocalMediaUseCase(repo).call('abc');
      expect(res, const Right<Failure, Unit>(unit));
      verify(() => repo.removeLocal('abc')).called(1);
    });

    test('propagates Left(Failure)', () async {
      when(() => repo.removeLocal(any())).thenAnswer(
        (_) async => const Left(Failure.errorFailure('perm denied')),
      );
      final res = await RemoveLocalMediaUseCase(repo).call('abc');
      expect(res.isLeft(), isTrue);
    });
  });

  // ── PublishMediaNoteUseCase ───────────────────────────────────────────────

  group('PublishMediaNoteUseCase', () {
    NoteEntity note() => aNote();

    test('saves the note then enqueues with imeta, returns the note',
        () async {
      final n = note();
      when(() => noteRepo.saveNote(any()))
          .thenAnswer((_) async => Right(n));
      when(() => queue.enqueueSignedEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sig: any(named: 'sig'),
            kind: any(named: 'kind'),
            eTagRefs: any(named: 'eTagRefs'),
            rootEventId: any(named: 'rootEventId'),
            replyToEventId: any(named: 'replyToEventId'),
            pTagRefs: any(named: 'pTagRefs'),
            tTags: any(named: 'tTags'),
            content: any(named: 'content'),
            created: any(named: 'created'),
            embeddedNoteJson: any(named: 'embeddedNoteJson'),
            imeta: any(named: 'imeta'),
          )).thenAnswer((_) async => const Right(1));

      final res = await PublishMediaNoteUseCase(noteRepo, queue).call(
        PublishMediaNoteInput(
          note: n,
          attachments: [aMediaBlob(sha256: 'a'), aPdfBlob()],
        ),
      );
      expect(res.isRight(), isTrue);
      final call = verify(() => queue.enqueueSignedEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sig: any(named: 'sig'),
            kind: any(named: 'kind'),
            eTagRefs: any(named: 'eTagRefs'),
            rootEventId: any(named: 'rootEventId'),
            replyToEventId: any(named: 'replyToEventId'),
            pTagRefs: any(named: 'pTagRefs'),
            tTags: any(named: 'tTags'),
            content: any(named: 'content'),
            created: any(named: 'created'),
            embeddedNoteJson: any(named: 'embeddedNoteJson'),
            imeta: captureAny(named: 'imeta'),
          )).captured;
      final imeta = call.single as List<MediaBlobEntity>;
      expect(imeta.map((a) => a.sha256).toList(), ['a', 'sha256-pdf']);
    });

    test('short-circuits when saveNote returns Left', () async {
      when(() => noteRepo.saveNote(any())).thenAnswer(
        (_) async => const Left(Failure.errorFailure('save failed')),
      );
      final res = await PublishMediaNoteUseCase(noteRepo, queue).call(
        PublishMediaNoteInput(note: note(), attachments: const []),
      );
      expect(res.isLeft(), isTrue);
      verifyNever(() => queue.enqueueSignedEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sig: any(named: 'sig'),
            kind: any(named: 'kind'),
            eTagRefs: any(named: 'eTagRefs'),
            rootEventId: any(named: 'rootEventId'),
            replyToEventId: any(named: 'replyToEventId'),
            pTagRefs: any(named: 'pTagRefs'),
            tTags: any(named: 'tTags'),
            content: any(named: 'content'),
            created: any(named: 'created'),
          ));
    });

    test('surfaces the queue Failure when enqueue returns Left', () async {
      final n = note();
      when(() => noteRepo.saveNote(any()))
          .thenAnswer((_) async => Right(n));
      when(() => queue.enqueueSignedEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sig: any(named: 'sig'),
            kind: any(named: 'kind'),
            eTagRefs: any(named: 'eTagRefs'),
            rootEventId: any(named: 'rootEventId'),
            replyToEventId: any(named: 'replyToEventId'),
            pTagRefs: any(named: 'pTagRefs'),
            tTags: any(named: 'tTags'),
            content: any(named: 'content'),
            created: any(named: 'created'),
            embeddedNoteJson: any(named: 'embeddedNoteJson'),
            imeta: any(named: 'imeta'),
          )).thenAnswer(
        (_) async => const Left(Failure.errorFailure('queue offline')),
      );
      final res = await PublishMediaNoteUseCase(noteRepo, queue).call(
        PublishMediaNoteInput(note: n, attachments: const []),
      );
      expect(res.isLeft(), isTrue);
      res.fold(
        (f) => expect(f.toMessage(), 'queue offline'),
        (_) => fail('expected Left'),
      );
    });
  });
}
