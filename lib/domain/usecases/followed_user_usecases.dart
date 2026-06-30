import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';
import 'package:uniun/domain/repositories/followed_user_repository.dart';

// ── Inputs ────────────────────────────────────────────────────────────────────

class FollowUserInput {
  const FollowUserInput({
    required this.pubkeyHex,
    this.relayHint,
    this.petname,
  });
  final String pubkeyHex;
  final String? relayHint;
  final String? petname;
}

// ── FollowUserUseCase ─────────────────────────────────────────────────────────

@lazySingleton
class FollowUserUseCase extends UseCase<Either<Failure, Unit>, FollowUserInput> {
  final FollowedUserRepository _repository;
  const FollowUserUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(
    FollowUserInput input, {
    bool cached = false,
  }) {
    return _repository.followUser(
      input.pubkeyHex,
      relayHint: input.relayHint,
      petname: input.petname,
    );
  }
}

// ── FollowUsersUseCase (batch) ────────────────────────────────────────────────

@lazySingleton
class FollowUsersUseCase
    extends UseCase<Either<Failure, Unit>, List<String>> {
  final FollowedUserRepository _repository;
  const FollowUsersUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(List<String> input, {bool cached = false}) {
    return _repository.followUsers(input);
  }
}

// ── UnfollowUserUseCase ───────────────────────────────────────────────────────

@lazySingleton
class UnfollowUserUseCase extends UseCase<Either<Failure, Unit>, String> {
  final FollowedUserRepository _repository;
  const UnfollowUserUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String pubkeyHex, {bool cached = false}) {
    return _repository.unfollowUser(pubkeyHex);
  }
}

// ── IsFollowingUseCase ────────────────────────────────────────────────────────

@lazySingleton
class IsFollowingUseCase extends UseCase<Either<Failure, bool>, String> {
  final FollowedUserRepository _repository;
  const IsFollowingUseCase(this._repository);

  @override
  Future<Either<Failure, bool>> call(String pubkeyHex, {bool cached = false}) {
    return _repository.isFollowing(pubkeyHex);
  }
}

// ── GetFollowedUsersUseCase ───────────────────────────────────────────────────

@lazySingleton
class GetFollowedUsersUseCase
    extends NoParamsUseCase<Either<Failure, List<FollowedUserEntity>>> {
  final FollowedUserRepository _repository;
  const GetFollowedUsersUseCase(this._repository);

  @override
  Future<Either<Failure, List<FollowedUserEntity>>> call() =>
      _repository.getAll();
}

// ── GetFollowedPubkeysUseCase ─────────────────────────────────────────────────

@lazySingleton
class GetFollowedPubkeysUseCase
    extends NoParamsUseCase<Either<Failure, List<String>>> {
  final FollowedUserRepository _repository;
  const GetFollowedPubkeysUseCase(this._repository);

  @override
  Future<Either<Failure, List<String>>> call() => _repository.getAllPubkeys();
}

// ── WatchFollowedUsersUseCase ─────────────────────────────────────────────────

@lazySingleton
class WatchFollowedUsersUseCase
    extends StreamUseCase<List<FollowedUserEntity>, void> {
  final FollowedUserRepository _repository;
  const WatchFollowedUsersUseCase(this._repository);

  @override
  Stream<List<FollowedUserEntity>> call(void _) => _repository.watchFollowed();
}
