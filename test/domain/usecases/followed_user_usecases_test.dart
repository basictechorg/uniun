import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';
import 'package:uniun/domain/repositories/followed_user_repository.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';

class _MockFollowedUserRepository extends Mock
    implements FollowedUserRepository {}

FollowedUserEntity _aFollowedUser() => FollowedUserEntity(
      pubkeyHex: 'pk',
      followedAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockFollowedUserRepository repo;

  setUp(() {
    repo = _MockFollowedUserRepository();
  });

  test('FollowUserUseCase forwards pubkey/relayHint/petname', () async {
    when(() => repo.followUser('pk', relayHint: 'wss://relay', petname: 'Alice'))
        .thenAnswer((_) async => const Right(unit));

    final result = await FollowUserUseCase(repo).call(
      const FollowUserInput(pubkeyHex: 'pk', relayHint: 'wss://relay', petname: 'Alice'),
    );

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => repo.followUser('pk', relayHint: 'wss://relay', petname: 'Alice')).called(1);
  });

  test('FollowUsersUseCase delegates a batch to followUsers', () async {
    when(() => repo.followUsers(['a', 'b'])).thenAnswer((_) async => const Right(unit));

    await FollowUsersUseCase(repo).call(['a', 'b']);

    verify(() => repo.followUsers(['a', 'b'])).called(1);
  });

  test('UnfollowUserUseCase delegates to unfollowUser', () async {
    when(() => repo.unfollowUser('pk')).thenAnswer((_) async => const Right(unit));

    final result = await UnfollowUserUseCase(repo).call('pk');

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('IsFollowingUseCase delegates to isFollowing', () async {
    when(() => repo.isFollowing('pk')).thenAnswer((_) async => const Right(true));

    final result = await IsFollowingUseCase(repo).call('pk');

    expect(result, const Right<Failure, bool>(true));
  });

  test('GetFollowedUsersUseCase delegates to getAll', () async {
    when(() => repo.getAll()).thenAnswer((_) async => Right([_aFollowedUser()]));

    final result = await GetFollowedUsersUseCase(repo).call();

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('GetFollowedPubkeysUseCase delegates to getAllPubkeys', () async {
    when(() => repo.getAllPubkeys()).thenAnswer((_) async => const Right(['a', 'b']));

    final result = await GetFollowedPubkeysUseCase(repo).call();

    expect(result, const Right<Failure, List<String>>(['a', 'b']));
  });

  test('WatchFollowedUsersUseCase forwards to watchFollowed', () {
    when(() => repo.watchFollowed()).thenAnswer((_) => Stream.value([_aFollowedUser()]));

    final stream = WatchFollowedUsersUseCase(repo).call(null);

    expect(stream, isA<Stream<List<FollowedUserEntity>>>());
    verify(() => repo.watchFollowed()).called(1);
  });
}
