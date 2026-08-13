import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/group_repository.dart';
import 'package:uniun/domain/usecases/create_group_usecase.dart';

import '../../_helpers/fixtures.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

class _MockEventQueueRepository extends Mock
    implements EventQueueRepository {}

const _testPrivkeyHex =
    '0000000000000000000000000000000000000000000000000000000000001';

void main() {
  late _MockGroupRepository groupRepo;
  late _MockEventQueueRepository queueRepo;

  setUpAll(() {
    registerFallbackValue(aGroup());
  });

  setUp(() {
    groupRepo = _MockGroupRepository();
    queueRepo = _MockEventQueueRepository();
    when(() => groupRepo.saveGroup(any()))
        .thenAnswer((i) async => Right(i.positionalArguments.first as GroupEntity));
    when(() => queueRepo.enqueueSignedEvent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          sig: any(named: 'sig'),
          kind: any(named: 'kind'),
          eTagRefs: any(named: 'eTagRefs'),
          pTagRefs: any(named: 'pTagRefs'),
          tTags: any(named: 'tTags'),
          content: any(named: 'content'),
          created: any(named: 'created'),
        )).thenAnswer((_) async => const Right(1));
  });

  test('creates a kind-40 group whose id is the signed event id, saves then '
      'enqueues', () async {
    final result = await CreateGroupUseCase(groupRepo, queueRepo).call(
      const CreateGroupInput(
        name: 'General',
        about: 'a group',
        picture: '',
        relays: ['wss://relay.example'],
        privateKey: _testPrivkeyHex,
      ),
    );

    expect(result.isRight(), isTrue);
    final group = result.getOrElse(() => aGroup());
    expect(group.name, 'General');
    expect(group.groupId, isNotEmpty);
    verify(() => groupRepo.saveGroup(any())).called(1);
  });

  test('a save failure short-circuits before enqueueing', () async {
    const failure = Failure.errorFailure('isar write failed');
    when(() => groupRepo.saveGroup(any())).thenAnswer((_) async => const Left(failure));

    final result = await CreateGroupUseCase(groupRepo, queueRepo).call(
      const CreateGroupInput(
        name: 'General',
        about: '',
        picture: '',
        relays: [],
        privateKey: _testPrivkeyHex,
      ),
    );

    expect(result, const Left<Failure, GroupEntity>(failure));
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
          content: any(named: 'content'),
          created: any(named: 'created'),
        )).thenAnswer((_) async => const Left(Failure.errorFailure('relay down')));

    final result = await CreateGroupUseCase(groupRepo, queueRepo).call(
      const CreateGroupInput(
        name: 'General',
        about: '',
        picture: '',
        relays: [],
        privateKey: _testPrivkeyHex,
      ),
    );

    expect(result.isLeft(), isTrue);
  });

  test('a malformed private key surfaces as a caught Left, not a throw',
      () async {
    final result = await CreateGroupUseCase(groupRepo, queueRepo).call(
      const CreateGroupInput(
        name: 'General',
        about: '',
        picture: '',
        relays: [],
        privateKey: 'not-a-valid-key',
      ),
    );

    expect(result.isLeft(), isTrue);
  });
}
