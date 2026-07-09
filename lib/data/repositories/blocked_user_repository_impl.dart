import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/blocked_user_model.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';
import 'package:uniun/domain/repositories/blocked_user_repository.dart';
import 'package:uniun/features/mesh/sync/bodies/blocked_user_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

@Injectable(as: BlockedUserRepository)
class BlockedUserRepositoryImpl extends BlockedUserRepository {
  final Isar isar;
  final MeshEventSigner _signer;
  BlockedUserRepositoryImpl({
    required this.isar,
    required MeshEventSigner signer,
  }) : _signer = signer;

  @override
  Future<Either<Failure, List<BlockedUserEntity>>> getAll() async {
    try {
      final models = await isar.blockedUserModels
          .filter()
          .removedAtIsNull()
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
      // Reactivate an existing tombstone rather than short-circuit if the row
      // was previously unblocked on this device — the user meant "block again".
      final existing = await isar.blockedUserModels
          .where()
          .pubkeyHexEqualTo(pubkeyHex)
          .findFirst();
      if (existing != null && existing.removedAt == null) {
        return const Right(unit);
      }

      final model = (existing ?? BlockedUserModel())
        ..pubkeyHex = pubkeyHex
        ..blockedAt = DateTime.now()
        ..removedAt = null;

      model.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.blockedUser,
        dTag: pubkeyHex,
        content: BlockedUserBody.forActive(model),
      );

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
      final model = await isar.blockedUserModels
          .where()
          .pubkeyHexEqualTo(pubkeyHex)
          .findFirst();
      if (model == null || model.removedAt != null) return const Right(unit);

      // Undo semantics per plan §5a: keep the row, flip to tombstone state,
      // re-sign a fresh mesh event with a NEWER `created_at`.
      model.removedAt = DateTime.now();
      model.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.blockedUser,
        dTag: pubkeyHex,
        content: BlockedUserBody.forRemoved(model),
      );

      await isar.writeTxn(() async {
        await isar.blockedUserModels.put(model);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
