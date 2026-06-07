import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';

abstract class BlockedUserRepository {
  Future<Either<Failure, List<BlockedUserEntity>>> getAll();
  Future<Either<Failure, Unit>> blockUser(String pubkeyHex);
  Future<Either<Failure, Unit>> unblockUser(String pubkeyHex);
}
