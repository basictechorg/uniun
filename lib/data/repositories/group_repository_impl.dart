import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/repositories/group_repository.dart';

@Injectable(as: GroupRepository)
class GroupRepositoryImpl extends GroupRepository {
  final Isar isar;

  GroupRepositoryImpl({required this.isar});

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
