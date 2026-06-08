import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';
import 'package:uniun/domain/repositories/blocked_user_repository.dart';

// ── GetBlockedUsersUseCase ────────────────────────────────────────────────────

@lazySingleton
class GetBlockedUsersUseCase
    extends NoParamsUseCase<Either<Failure, List<BlockedUserEntity>>> {
  final BlockedUserRepository _repository;
  const GetBlockedUsersUseCase(this._repository);

  @override
  Future<Either<Failure, List<BlockedUserEntity>>> call() {
    return _repository.getAll();
  }
}

// ── BlockUserUseCase ──────────────────────────────────────────────────────────

@lazySingleton
class BlockUserUseCase extends UseCase<Either<Failure, Unit>, String> {
  final BlockedUserRepository _repository;
  const BlockUserUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String pubkeyHex, {bool cached = false}) {
    return _repository.blockUser(pubkeyHex);
  }
}

// ── UnblockUserUseCase ────────────────────────────────────────────────────────

@lazySingleton
class UnblockUserUseCase extends UseCase<Either<Failure, Unit>, String> {
  final BlockedUserRepository _repository;
  const UnblockUserUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String pubkeyHex, {bool cached = false}) {
    return _repository.unblockUser(pubkeyHex);
  }
}
