import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/domain/repositories/unread_repository.dart';

@Injectable(as: UnreadRepository)
class UnreadRepositoryImpl extends UnreadRepository {
  final Isar isar;
  UnreadRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, Unit>> markSeen(String eventId) async {
    try {
      await isar.writeTxn(() async {
        await isar.unreadNoteModels
            .filter()
            .eventIdEqualTo(eventId)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markGroupSeen(String groupId) async {
    try {
      await isar.writeTxn(() async {
        await isar.unreadNoteModels
            .filter()
            .groupIdEqualTo(groupId)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markPrivateGroupSeen(String privateGroupId) async {
    try {
      await isar.writeTxn(() async {
        await isar.unreadNoteModels
            .filter()
            .privateGroupIdEqualTo(privateGroupId)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markConversationSeen(int conversationId) async {
    try {
      await isar.writeTxn(() async {
        await isar.unreadNoteModels
            .filter()
            .conversationIdEqualTo(conversationId)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DateTime?>> oldestUnreadTimeForGroup(
    String groupId,
  ) async {
    try {
      final row = await isar.unreadNoteModels
          .filter()
          .groupIdEqualTo(groupId)
          .sortByCreated()
          .findFirst();
      return Right(row?.created);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
