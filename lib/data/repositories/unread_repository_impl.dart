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
  Future<Either<Failure, Unit>> markChannelSeen(String channelId) async {
    try {
      await isar.writeTxn(() async {
        await isar.unreadNoteModels
            .filter()
            .channelIdEqualTo(channelId)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markPrivateChannelSeen(String groupId) async {
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
}
