import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/repositories/group_repository.dart';
import 'package:uniun/features/mesh/sync/bodies/group_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

@Injectable(as: GroupRepository)
class GroupRepositoryImpl extends GroupRepository {
  final Isar isar;
  final MeshEventSigner _signer;

  GroupRepositoryImpl({required this.isar, required MeshEventSigner signer})
      : _signer = signer;

  @override
  Future<Either<Failure, GroupEntity>> saveGroup(
    GroupEntity group,
  ) async {
    try {
      final existing = await isar.groupModels
          .where()
          .groupIdEqualTo(group.groupId)
          .findFirst();

      final model = existing ?? GroupModel();
      model.groupId = group.groupId;
      model.creatorPubKey = group.creatorPubKey;
      model.name = group.name;
      model.about = group.about;
      model.picture = group.picture;
      model.relays = List<String>.from(group.relays);
      model.createdAt = group.createdAt;
      model.updatedAt = group.updatedAt;
      model.lastMetaEvent = group.lastMetaEvent;

      // Stamp the same-identity mesh event so the group syncs to the user's
      // other devices over BLE / LAN (no relay). Membership toggles ON here, so
      // clear any tombstone. Sign is best-effort: a logged-out signer leaves
      // the column null (the migration pass backfills it later).
      model.removedAt = null;
      model.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.group,
        dTag: group.groupId,
        content: GroupBody.forActive(model),
      );

      await isar.writeTxn(() async {
        await isar.groupModels.put(model);
      });

      return Right(model.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> updateGroupMetadata(
    String groupId,
    String metaEventId,
    int metaEventCreatedAt,
    String name,
    String about,
    String picture,
  ) async {
    try {
      final existing = await isar.groupModels
          .where()
          .groupIdEqualTo(groupId)
          .findFirst();
      if (existing == null) {
        return Left(
          Failure.notFoundFailure('Group not found for id: $groupId'),
        );
      }

      // Guard against out-of-order metadata events from relays.
      if (metaEventCreatedAt <= existing.updatedAt) {
        return Right(existing.toDomain());
      }

      await isar.writeTxn(() async {
        existing.name = name;
        existing.about = about;
        existing.picture = picture;
        existing.updatedAt = metaEventCreatedAt;
        existing.lastMetaEvent = metaEventId;

        // Keep the mesh event in sync with the updated metadata so peers
        // receive the latest group snapshot. Sign is best-effort — a logged-out
        // signer leaves the column untouched and the migration pass backfills.
        if (existing.removedAt == null) {
          existing.signedNostrEvent =
              await _signer.sign(
                kind: MeshEventKinds.group,
                dTag: groupId,
                content: GroupBody.forActive(existing),
              ) ??
              existing.signedNostrEvent;
        }

        await isar.groupModels.put(existing);
      });

      return Right(existing.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> getGroups() async {
    try {
      final rows = await isar.groupModels.where().findAll();
      return Right(rows.map((c) => c.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> getGroupById(
    String groupId,
  ) async {
    try {
      final group = await isar.groupModels
          .where()
          .groupIdEqualTo(groupId)
          .findFirst();
      if (group == null) {
        return Left(
          Failure.notFoundFailure('Group not found for id: $groupId'),
        );
      }
      return Right(group.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
