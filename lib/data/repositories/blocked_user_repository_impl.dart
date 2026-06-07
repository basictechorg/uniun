import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/blocked_user_model.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';
import 'package:uniun/domain/repositories/blocked_user_repository.dart';

@Injectable(as: BlockedUserRepository)
class BlockedUserRepositoryImpl extends BlockedUserRepository {
  final Isar isar;
  BlockedUserRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, List<BlockedUserEntity>>> getAll() async {
    try {
      final models = await isar.blockedUserModels
          .where()
          .sortByBlockedAtDesc()
          .findAll();
      return Right(models.map((m) => m.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> blockUser(String pubkeyHex) async {
    try {
      final existing = await isar.blockedUserModels
          .where()
          .pubkeyHexEqualTo(pubkeyHex)
          .findFirst();
      if (existing != null) return const Right(unit);

      final model = BlockedUserModel()
        ..pubkeyHex = pubkeyHex
        ..blockedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.blockedUserModels.put(model);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> unblockUser(String pubkeyHex) async {
    try {
      await isar.writeTxn(() async {
        await isar.blockedUserModels
            .where()
            .pubkeyHexEqualTo(pubkeyHex)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
