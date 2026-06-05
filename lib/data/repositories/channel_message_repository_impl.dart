import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
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
  Future<Either<Failure, NoteEntity>> saveMessage(NoteEntity message) async {
    try {
      final existing = await isar.noteModels
          .where()
          .eventIdEqualTo(message.id)
          .findFirst();
      if (existing != null) {
        return Right(_toChannelDomain(existing));
      }

      final model = NoteModel(
        eventId: message.id,
        sig: message.sig,
        authorPubkey: message.authorPubkey,
        content: message.content,
        kind: kChannelMessageKind,
        channelId: message.sourceChannelId,
        type: NoteType.text,
        eTagRefs: List<String>.from(message.eTagRefs),
        pTagRefs: List<String>.from(message.pTagRefs),
        rootEventId: message.rootEventId,
        replyToEventId: message.replyToEventId,
        tTags: const [],
        created: message.created,
        isSeen: false,
      );

      final parents = replyEdgeParentIds(
        replyToEventId: message.replyToEventId,
        rootEventId: message.rootEventId,
        eTagRefs: message.eTagRefs,
      );
      await isar.writeTxn(() async {
        await isar.noteModels.put(model);
        await _relations.addEdgesInTxn(parents: parents, childId: message.id);
      });

      return Right(_toChannelDomain(model));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> getMessagesForChannel({
    required String channelId,
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      final List<NoteModel> rows;
      if (before != null) {
        rows = await isar.noteModels
            .filter()
            .channelIdEqualTo(channelId)
            .createdLessThan(before)
            .sortByCreatedDesc()
            .limit(limit)
            .findAll();
      } else {
        rows = await isar.noteModels
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

  /// A channel message stores the channel root and its direct reply parent
  /// inside [NoteModel.eTagRefs]. Strip those here so the resulting entity's
  /// `eTagRefs` carries only genuine mention references.
  NoteEntity _toChannelDomain(NoteModel m) {
    final e = m.toDomain();
    return e.copyWith(
      eTagRefs: e.eTagRefs
          .where((id) => id != m.channelId && id != m.replyToEventId)
          .toList(),
    );
  }

  /// Stitches the live reply + reference counts onto each entity from the
  /// edge table (reply = edges pointing to it; reference = edges from it).
  Future<List<NoteEntity>> _withReplyCounts(List<NoteModel> models) async {
    final entities = models.map(_toChannelDomain).toList();
    return [
      for (final e in entities)
        e.copyWith(
          cachedReplyCount: await _relations.replyCount(e.id),
          referenceCount: await _relations.referenceCount(e.id),
        ),
    ];
  }

  @override
  Future<Either<Failure, NoteEntity?>> getMessageByEventId(
    String eventId,
  ) async {
    try {
      final row = await isar.noteModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
      return Right(row == null ? null : _toChannelDomain(row));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> getChannelMessageReplies(
    String messageId,
  ) async {
    try {
      // Query by eTagRefs containing messageId — matches both direct replies
      // (replyToEventId) and mention references, mirroring Vishnu note behaviour.
      final rows = await isar.noteModels
          .filter()
          .channelIdIsNotNull()
          .and()
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
