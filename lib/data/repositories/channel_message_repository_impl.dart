import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/channel_message_model.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';
import 'package:uniun/domain/repositories/channel_message_repository.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';

@Injectable(as: ChannelMessageRepository)
class ChannelMessageRepositoryImpl extends ChannelMessageRepository {
  final Isar isar;
  final NoteRelationRepository _relations;

  ChannelMessageRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
  }) : _relations = relations;

  @override
  Future<Either<Failure, ChannelMessageEntity>> saveMessage(
    ChannelMessageEntity message,
  ) async {
    try {
      final existing = await isar.channelMessageModels
          .where()
          .eventIdEqualTo(message.id)
          .findFirst();
      if (existing != null) {
        return Right(existing.toDomain());
      }

      final model = ChannelMessageModel()
        ..eventId = message.id
        ..channelId = message.channelId
        ..sig = message.sig
        ..authorPubkey = message.authorPubkey
        ..content = message.content
        ..eTagRefs = List<String>.from(message.eTagRefs)
        ..pTagRefs = List<String>.from(message.pTagRefs)
        ..rootEventId = message.rootEventId
        ..replyToEventId = message.replyToEventId
        ..created = message.created;

      final parents = replyEdgeParentIds(
        replyToEventId: message.replyToEventId,
        rootEventId: message.rootEventId,
        eTagRefs: message.eTagRefs,
      );
      await isar.writeTxn(() async {
        await isar.channelMessageModels.put(model);
        await _relations.addEdgesInTxn(parents: parents, childId: message.id);
      });

      return Right(model.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChannelMessageEntity>>> getMessagesForChannel({
    required String channelId,
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      final List<ChannelMessageModel> rows;
      if (before != null) {
        rows = await isar.channelMessageModels
            .filter()
            .channelIdEqualTo(channelId)
            .createdLessThan(before)
            .sortByCreatedDesc()
            .limit(limit)
            .findAll();
      } else {
        rows = await isar.channelMessageModels
            .filter()
            .channelIdEqualTo(channelId)
            .sortByCreatedDesc()
            .limit(limit)
            .findAll();
      }

      return Right(await _withReplyCounts(rows));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// Stitches the live reply + reference counts onto each entity from the
  /// edge table (reply = edges pointing to it; reference = edges from it).
  Future<List<ChannelMessageEntity>> _withReplyCounts(
    List<ChannelMessageModel> models,
  ) async {
    final entities = models.map((m) => m.toDomain()).toList();
    return [
      for (final e in entities)
        e.copyWith(
          cachedReplyCount: await _relations.replyCount(e.id),
          referenceCount: await _relations.referenceCount(e.id),
        ),
    ];
  }

  @override
  Future<Either<Failure, ChannelMessageEntity?>> getMessageByEventId(
    String eventId,
  ) async {
    try {
      final row = await isar.channelMessageModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
      return Right(row?.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChannelMessageEntity>>> getChannelMessageReplies(
    String messageId,
  ) async {
    try {
      // Query by eTagRefs containing messageId — matches both direct replies
      // (replyToEventId) and mention references, mirroring Vishnu note behaviour.
      final rows = await isar.channelMessageModels
          .filter()
          .eTagRefsElementEqualTo(messageId)
          .sortByCreated()
          .findAll();
      return Right(await _withReplyCounts(rows));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getChannelMessageReplyCount(
    String messageId,
  ) async {
    try {
      return Right(await _relations.replyCount(messageId));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
