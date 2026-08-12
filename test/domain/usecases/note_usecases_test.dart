import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/inputs/note_input.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/note_repository.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MockNoteRepository extends Mock implements NoteRepository {}

class _MockNoteRelationRepository extends Mock
    implements NoteRelationRepository {}

class _MockEventQueueRepository extends Mock
    implements EventQueueRepository {}

void main() {
  late _MockNoteRepository noteRepo;
  late _MockNoteRelationRepository relationRepo;
  late _MockEventQueueRepository queueRepo;

  setUpAll(() {
    registerFallbackValue(aNote());
  });

  setUp(() {
    noteRepo = _MockNoteRepository();
    relationRepo = _MockNoteRelationRepository();
    queueRepo = _MockEventQueueRepository();
  });

  group('GetFeedUseCase', () {
    test('forwards limit/before and returns the feed', () async {
      final before = DateTime(2026, 1, 1);
      when(() => noteRepo.getFeed(limit: 20, before: before))
          .thenAnswer((_) async => Right([aNote()]));

      final result =
          await GetFeedUseCase(noteRepo).call(GetFeedInput(limit: 20, before: before));

      expect(result.getOrElse(() => []), hasLength(1));
      verify(() => noteRepo.getFeed(limit: 20, before: before)).called(1);
    });
  });

  group('GetNoteByIdUseCase', () {
    test('delegates to getNoteById', () async {
      when(() => noteRepo.getNoteById('n1')).thenAnswer((_) async => Right(aNote(id: 'n1')));

      final result = await GetNoteByIdUseCase(noteRepo).call('n1');

      expect(result.getOrElse(() => aNote()).id, 'n1');
    });

    test('propagates a repository failure', () async {
      const failure = Failure.errorFailure('not found');
      when(() => noteRepo.getNoteById('missing'))
          .thenAnswer((_) async => const Left(failure));

      final result = await GetNoteByIdUseCase(noteRepo).call('missing');

      expect(result, const Left<Failure, NoteEntity>(failure));
    });
  });

  group('GetRepliesUseCase', () {
    test('delegates to getReplies', () async {
      when(() => noteRepo.getReplies('root')).thenAnswer((_) async => Right([aNote()]));

      final result = await GetRepliesUseCase(noteRepo).call('root');

      expect(result.isRight(), isTrue);
      verify(() => noteRepo.getReplies('root')).called(1);
    });
  });

  group('SaveNoteUseCase', () {
    test('delegates to saveNote', () async {
      final note = aNote();
      when(() => noteRepo.saveNote(note)).thenAnswer((_) async => Right(note));

      final result = await SaveNoteUseCase(noteRepo).call(note);

      expect(result, Right<Failure, NoteEntity>(note));
    });
  });

  group('GetThreadUseCase', () {
    test('delegates to getThread', () async {
      when(() => noteRepo.getThread('root')).thenAnswer((_) async => Right([aNote()]));

      await GetThreadUseCase(noteRepo).call('root');

      verify(() => noteRepo.getThread('root')).called(1);
    });
  });

  group('GetReplyCountUseCase / GetThreadReplyCountUseCase', () {
    test('reply count delegates', () async {
      when(() => noteRepo.getReplyCount('n1')).thenAnswer((_) async => const Right(3));

      final result = await GetReplyCountUseCase(noteRepo).call('n1');

      expect(result, const Right<Failure, int>(3));
    });

    test('thread reply count delegates', () async {
      when(() => noteRepo.getThreadReplyCount('root')).thenAnswer((_) async => const Right(5));

      final result = await GetThreadReplyCountUseCase(noteRepo).call('root');

      expect(result, const Right<Failure, int>(5));
    });
  });

  group('GetNoteRelationCountsUseCase', () {
    test('aggregates comments/references per id', () async {
      when(() => relationRepo.replyCount('a')).thenAnswer((_) async => 2);
      when(() => relationRepo.referenceCount('a')).thenAnswer((_) async => 1);
      when(() => relationRepo.replyCount('b')).thenAnswer((_) async => 0);
      when(() => relationRepo.referenceCount('b')).thenAnswer((_) async => 4);

      final result =
          await GetNoteRelationCountsUseCase(relationRepo).call(['a', 'b']);

      final map = result.getOrElse(() => {});
      expect(map['a']!.comments, 2);
      expect(map['a']!.references, 1);
      expect(map['b']!.comments, 0);
      expect(map['b']!.references, 4);
    });

    test('a repository throw degrades to Left', () async {
      when(() => relationRepo.replyCount(any())).thenThrow(Exception('boom'));

      final result = await GetNoteRelationCountsUseCase(relationRepo).call(['a']);

      expect(result.isLeft(), isTrue);
    });
  });

  group('GetOwnNotesUseCase', () {
    test('delegates to getOwnNotes', () async {
      when(() => noteRepo.getOwnNotes('pk')).thenAnswer((_) async => Right([aNote()]));

      await GetOwnNotesUseCase(noteRepo).call('pk');

      verify(() => noteRepo.getOwnNotes('pk')).called(1);
    });
  });

  group('SearchNotesUseCase', () {
    test('delegates to searchNotes', () async {
      when(() => noteRepo.searchNotes('hello')).thenAnswer((_) async => Right([aNote()]));

      await SearchNotesUseCase(noteRepo).call('hello');

      verify(() => noteRepo.searchNotes('hello')).called(1);
    });
  });

  group('PublishNoteUseCase', () {
    test('saves locally then enqueues, returning the saved note', () async {
      final note = aNote();
      when(() => noteRepo.saveNote(note)).thenAnswer((_) async => Right(note));
      when(() => queueRepo.enqueueSignedEvent(
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
          )).thenAnswer((_) async => const Right(1));

      final result = await PublishNoteUseCase(noteRepo, queueRepo).call(note);

      expect(result, Right<Failure, NoteEntity>(note));
      verify(() => noteRepo.saveNote(note)).called(1);
      verify(() => queueRepo.enqueueSignedEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sig: any(named: 'sig'),
            kind: 1,
            eTagRefs: any(named: 'eTagRefs'),
            rootEventId: any(named: 'rootEventId'),
            replyToEventId: any(named: 'replyToEventId'),
            pTagRefs: any(named: 'pTagRefs'),
            tTags: any(named: 'tTags'),
            content: any(named: 'content'),
            created: any(named: 'created'),
            embeddedNoteJson: any(named: 'embeddedNoteJson'),
          )).called(1);
    });

    test('a local-save failure short-circuits before enqueueing', () async {
      const failure = Failure.errorFailure('isar write failed');
      final note = aNote();
      when(() => noteRepo.saveNote(note)).thenAnswer((_) async => const Left(failure));

      final result = await PublishNoteUseCase(noteRepo, queueRepo).call(note);

      expect(result, const Left<Failure, NoteEntity>(failure));
      verifyNever(() => queueRepo.enqueueSignedEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sig: any(named: 'sig'),
            kind: any(named: 'kind'),
            eTagRefs: any(named: 'eTagRefs'),
            pTagRefs: any(named: 'pTagRefs'),
            tTags: any(named: 'tTags'),
            content: any(named: 'content'),
            created: any(named: 'created'),
          ));
    });

    test('an enqueue failure surfaces as Left even though the save succeeded',
        () async {
      final note = aNote();
      when(() => noteRepo.saveNote(note)).thenAnswer((_) async => Right(note));
      when(() => queueRepo.enqueueSignedEvent(
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
          )).thenAnswer(
              (_) async => const Left(Failure.errorFailure('relay down')));

      final result = await PublishNoteUseCase(noteRepo, queueRepo).call(note);

      expect(result.isLeft(), isTrue);
    });
  });
}
