import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';

abstract class GroupRepository {
  Future<Either<Failure, GroupEntity>> saveGroup(GroupEntity group);

  Future<Either<Failure, GroupEntity>> updateGroupMetadata(
    String groupId,
    String metaEventId,
    int metaEventCreatedAt,
    String name,
    String about,
    String picture,
  );

  Future<Either<Failure, List<GroupEntity>>> getGroups();

  Future<Either<Failure, GroupEntity>> getGroupById(String groupId);
}
