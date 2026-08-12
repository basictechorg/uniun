import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockEventQueueRepository extends Mock
    implements EventQueueRepository {}

class _MockGetActiveUserKeys extends Mock
    implements GetActiveUserKeysUseCase {}

void main() {
  late _MockProfileRepository profileRepo;
  late _MockEventQueueRepository queueRepo;
  late _MockGetActiveUserKeys getKeys;

  setUpAll(() {
    registerFallbackValue(aProfile());
  });

  setUp(() {
    profileRepo = _MockProfileRepository();
    queueRepo = _MockEventQueueRepository();
    getKeys = _MockGetActiveUserKeys();
  });

  test('GetProfileUseCase delegates to getProfile', () async {
    when(() => profileRepo.getProfile('pk')).thenAnswer((_) async => Right(aProfile()));

    await GetProfileUseCase(profileRepo).call('pk');

    verify(() => profileRepo.getProfile('pk')).called(1);
  });

  test('GetOwnProfileUseCase delegates to getOwnProfile', () async {
    when(() => profileRepo.getOwnProfile('pk')).thenAnswer((_) async => Right(aProfile()));

    final result = await GetOwnProfileUseCase(profileRepo).call('pk');

    expect(result.isRight(), isTrue);
  });

  test('SaveProfileUseCase delegates to saveProfile', () async {
    final profile = aProfile();
    when(() => profileRepo.saveProfile(profile)).thenAnswer((_) async => Right(profile));

    final result = await SaveProfileUseCase(profileRepo).call(profile);

    expect(result, Right<Failure, ProfileEntity>(profile));
  });

  test('WatchProfileUseCase forwards to watchProfile', () {
    when(() => profileRepo.watchProfile('pk')).thenAnswer((_) => Stream.value(aProfile()));

    final stream = WatchProfileUseCase(profileRepo).call('pk');

    expect(stream, isA<Stream<ProfileEntity?>>());
    verify(() => profileRepo.watchProfile('pk')).called(1);
  });

  test('RequestProfileFetchUseCase delegates to requestProfileFetch',
      () async {
    when(() => profileRepo.requestProfileFetch('pk')).thenAnswer((_) async => const Right(unit));

    final result = await RequestProfileFetchUseCase(profileRepo).call('pk');

    expect(result, const Right<Failure, Unit>(unit));
  });

  group('PublishProfileMetadataUseCase', () {
    setUp(() {
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

    test('signs a kind-0 event with the active user keys and enqueues it',
        () async {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(
              privkeyHex:
                  '0000000000000000000000000000000000000000000000000000000000001',
              pubkeyHex: 'pk',
            ),
          ));

      final result = await PublishProfileMetadataUseCase(queueRepo, getKeys)
          .call(aProfile(name: 'Alice'));

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => queueRepo.enqueueSignedEvent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sig: any(named: 'sig'),
            kind: 0,
            eTagRefs: any(named: 'eTagRefs'),
            pTagRefs: any(named: 'pTagRefs'),
            tTags: any(named: 'tTags'),
            content: any(named: 'content'),
            created: any(named: 'created'),
          )).called(1);
    });

    test('a key-fetch failure short-circuits before touching the queue',
        () async {
      const failure = Failure.errorFailure('no active user');
      when(() => getKeys.call()).thenAnswer((_) async => const Left(failure));

      final result =
          await PublishProfileMetadataUseCase(queueRepo, getKeys).call(aProfile());

      expect(result, const Left<Failure, Unit>(failure));
      verifyZeroInteractions(queueRepo);
    });

    test('an enqueue failure surfaces as Left', () async {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(
              privkeyHex:
                  '0000000000000000000000000000000000000000000000000000000000001',
              pubkeyHex: 'pk',
            ),
          ));
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

      final result =
          await PublishProfileMetadataUseCase(queueRepo, getKeys).call(aProfile());

      expect(result.isLeft(), isTrue);
    });

    test('a malformed private key surfaces as a caught Left, not a throw',
        () async {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(privkeyHex: 'not-a-valid-key', pubkeyHex: 'pk'),
          ));

      final result =
          await PublishProfileMetadataUseCase(queueRepo, getKeys).call(aProfile());

      expect(result.isLeft(), isTrue);
    });
  });
}
