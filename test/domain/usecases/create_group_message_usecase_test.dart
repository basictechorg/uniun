import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/group_message_repository.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';

import '../../_helpers/fixtures.dart';

class _MockGroupMessageRepository extends Mock
    implements GroupMessageRepository {}

class _MockEventQueueRepository extends Mock
    implements EventQueueRepository {}

/// A real (unsigned-with-a-test-key) `nostr` Event.from call happens inside
/// the use case — no seam to mock it out, so these tests exercise the real
/// signing path with a syntactically valid 32-byte hex private key.
const _testPrivkeyHex =
    '0000000000000000000000000000000000000000000000000000000000001';

void main() {
  late _MockGroupMessageRepository groupMessageRepo;
  late _MockEventQueueRepository queueRepo;

  setUpAll(() {
    registerFallbackValue(aNote());
  });

  setUp(() {
    groupMessageRepo = _MockGroupMessageRepository();
    queueRepo = _MockEventQueueRepository();
    when(() => groupMessageRepo.saveMessage(any()))
        .thenAnswer((i) async => Right(i.positionalArguments.first as NoteEntity));
    when(() => queueRepo.enqueueSignedEvent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          sig: any(named: 'sig'),
          kind: any(named: 'kind'),
          eTagRefs: any(named: 'eTagRefs'),
          pTagRefs: any(named: 'pTagRefs'),
          tTags: any(named: 'tTags'),
          rootEventId: any(named: 'rootEventId'),
          replyToEventId: any(named: 'replyToEventId'),
          content: any(named: 'content'),
          created: any(named: 'created'),
          embeddedNoteJson: any(named: 'embeddedNoteJson'),
          imeta: any(named: 'imeta'),
        )).thenAnswer((_) async => const Right(1));
  });

  test('builds a kind-42 message rooted at the group, saves then enqueues',
      () async {
    final result = await CreateGroupMessageUseCase(groupMessageRepo, queueRepo)
        .call(const CreateGroupMessageInput(
      groupId: 'group-1',
      content: 'hello group',
      privateKey: _testPrivkeyHex,
    ));

    expect(result.isRight(), isTrue);
    final message = result.getOrElse(() => aNote());
    expect(message.sourceGroupId, 'group-1');
    expect(message.rootEventId, 'group-1');
    expect(message.content, 'hello group');
    verify(() => groupMessageRepo.saveMessage(any())).called(1);
  });

  test('a reply carries the reply e-tag and replyToEventId', () async {
    final result = await CreateGroupMessageUseCase(groupMessageRepo, queueRepo)
        .call(const CreateGroupMessageInput(
      groupId: 'group-1',
      content: 'a reply',
      privateKey: _testPrivkeyHex,
      replyToEventId: 'parent-1',
      mentionRefs: ['mention-1'],
    ));

    final message = result.getOrElse(() => aNote());
    expect(message.replyToEventId, 'parent-1');
    expect(message.eTagRefs, containsAll(['group-1', 'parent-1', 'mention-1']));
  });

  test('a save failure short-circuits before enqueueing', () async {
    const failure = Failure.errorFailure('isar write failed');
    when(() => groupMessageRepo.saveMessage(any()))
        .thenAnswer((_) async => const Left(failure));

    final result = await CreateGroupMessageUseCase(groupMessageRepo, queueRepo)
        .call(const CreateGroupMessageInput(
      groupId: 'group-1',
      content: 'hello',
      privateKey: _testPrivkeyHex,
    ));

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

  test('an enqueue failure surfaces as Left', () async {
    when(() => queueRepo.enqueueSignedEvent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          sig: any(named: 'sig'),
          kind: any(named: 'kind'),
          eTagRefs: any(named: 'eTagRefs'),
          pTagRefs: any(named: 'pTagRefs'),
          tTags: any(named: 'tTags'),
          rootEventId: any(named: 'rootEventId'),
          replyToEventId: any(named: 'replyToEventId'),
          content: any(named: 'content'),
          created: any(named: 'created'),
          embeddedNoteJson: any(named: 'embeddedNoteJson'),
          imeta: any(named: 'imeta'),
        )).thenAnswer((_) async => const Left(Failure.errorFailure('relay down')));

    final result = await CreateGroupMessageUseCase(groupMessageRepo, queueRepo)
        .call(const CreateGroupMessageInput(
      groupId: 'group-1',
      content: 'hello',
      privateKey: _testPrivkeyHex,
    ));

    expect(result.isLeft(), isTrue);
  });

  test('a malformed private key surfaces as a caught Left, not a throw',
      () async {
    final result = await CreateGroupMessageUseCase(groupMessageRepo, queueRepo)
        .call(const CreateGroupMessageInput(
      groupId: 'group-1',
      content: 'hello',
      privateKey: 'not-a-valid-key',
    ));

    expect(result.isLeft(), isTrue);
  });
}
