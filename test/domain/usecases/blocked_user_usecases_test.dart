import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';
import 'package:uniun/domain/repositories/blocked_user_repository.dart';
import 'package:uniun/domain/usecases/blocked_user_usecases.dart';

class _MockBlockedUserRepository extends Mock
    implements BlockedUserRepository {}

void main() {
  late _MockBlockedUserRepository repo;

  setUp(() {
    repo = _MockBlockedUserRepository();
  });

  test('GetBlockedUsersUseCase delegates to getAll', () async {
    when(() => repo.getAll()).thenAnswer((_) async => Right([
          BlockedUserEntity(pubkeyHex: 'pk', blockedAt: DateTime(2026, 1, 1)),
        ]));

    final result = await GetBlockedUsersUseCase(repo).call();

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('BlockUserUseCase delegates to blockUser', () async {
    when(() => repo.blockUser('pk')).thenAnswer((_) async => const Right(unit));

    final result = await BlockUserUseCase(repo).call('pk');

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('UnblockUserUseCase delegates to unblockUser', () async {
    when(() => repo.unblockUser('pk')).thenAnswer((_) async => const Right(unit));

    final result = await UnblockUserUseCase(repo).call('pk');

    expect(result, const Right<Failure, Unit>(unit));
  });
}
