import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/channel_message_model.dart';
import 'package:uniun/data/models/dm/dm_message_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/private_channel_message_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';

@Injectable(as: NoteResolverRepository)
class NoteResolverRepositoryImpl implements NoteResolverRepository {
  final Isar isar;
  NoteResolverRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, ResolvedNote>> resolveById(String id) async {
    try {
      final note =
          await isar.noteModels.where().eventIdEqualTo(id).findFirst();
      if (note != null) {
        return Right(ResolvedNote(
          note: note.toDomain(),
          source: NoteSource.feed,
        ));
      }

      final channel =
          await isar.channelMessageModels.where().eventIdEqualTo(id).findFirst();
      if (channel != null) {
        return Right(ResolvedNote(
          note: _fromChannel(channel),
          source: NoteSource.channel,
          channelId: channel.channelId,
        ));
      }

      final private = await isar.privateChannelMessageModels
          .where()
          .eventIdEqualTo(id)
          .findFirst();
      if (private != null) {
        return Right(ResolvedNote(
          note: _fromPrivate(private),
          source: NoteSource.privateChannel,
          groupId: private.groupId,
        ));
      }

      final dm =
          await isar.dmMessageModels.where().eventIdEqualTo(id).findFirst();
      if (dm != null) {
        return Right(ResolvedNote(
          note: _fromDm(dm),
          source: NoteSource.dm,
          dmReceiverPubkey: dm.pTagRefs.isNotEmpty ? dm.pTagRefs.first : null,
        ));
      }

      return Left(Failure.notFoundFailure('Note not found: $id'));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, NoteEntity?>> resolveNoteById(String id) async {
    final result = await resolveById(id);
    // Not-found resolves to null rather than an error (parent/mention may be
    // absent locally); only real failures propagate.
    return result.fold((_) => const Right(null), (r) => Right(r.note));
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> resolveReplies(String id) async {
    try {
      final out = <NoteEntity>[];

      out.addAll((await isar.noteModels
              .filter()
              .replyToEventIdEqualTo(id)
              .findAll())
          .map((m) => m.toDomain()));
      out.addAll((await isar.channelMessageModels
              .filter()
              .replyToEventIdEqualTo(id)
              .findAll())
          .map(_fromChannel));
      out.addAll((await isar.privateChannelMessageModels
              .filter()
              .replyToEventIdEqualTo(id)
              .findAll())
          .map(_fromPrivate));
      out.addAll((await isar.dmMessageModels
              .filter()
              .replyToEventIdEqualTo(id)
              .findAll())
          .map(_fromDm));

      final seen = <String>{};
      final deduped = out.where((n) => seen.add(n.id)).toList()
        ..sort((a, b) => a.created.compareTo(b.created));
      return Right(deduped);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> resolveMany(
      List<String> ids) async {
    try {
      final out = <NoteEntity>[];
      for (final id in ids) {
        final r = await resolveNoteById(id);
        r.fold((_) {}, (note) {
          if (note != null) out.add(note);
        });
      }
      return Right(out);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Model → canonical NoteEntity ──────────────────────────────────────────

  NoteEntity _fromChannel(ChannelMessageModel m) => NoteEntity(
        id: m.eventId,
        sig: m.sig,
        authorPubkey: m.authorPubkey,
        content: m.content,
        type: NoteType.text,
        eTagRefs: List<String>.from(m.eTagRefs),
        pTagRefs: List<String>.from(m.pTagRefs),
        tTags: const [],
        created: m.created,
        isSeen: true,
        rootEventId: m.rootEventId,
        replyToEventId: m.replyToEventId,
        // Reply count now comes from NoteRelationRepository in the feed
        // pipeline. The resolver is used for one-off lookups (thread root,
        // mentions) where the live count isn't displayed, so default to 0.
      );

  NoteEntity _fromPrivate(PrivateChannelMessageModel m) => NoteEntity(
        id: m.eventId,
        sig: '',
        authorPubkey: m.senderPubkey,
        content: m.decryptedContent,
        type: NoteType.text,
        eTagRefs: List<String>.from(m.eTagRefs),
        pTagRefs: List<String>.from(m.pTagRefs),
        tTags: const [],
        created: m.timestamp,
        isSeen: true,
        rootEventId: m.rootEventId,
        replyToEventId: m.replyToEventId,
      );

  NoteEntity _fromDm(DmMessageModel m) => NoteEntity(
        id: m.eventId,
        sig: m.sig,
        authorPubkey: m.authorPubkey,
        content: m.content,
        subject: m.subject,
        type: m.type,
        eTagRefs: List<String>.from(m.eTagRefs),
        pTagRefs: List<String>.from(m.pTagRefs),
        tTags: const [],
        created: m.created,
        isSeen: m.isSeen,
        rootEventId: m.rootEventId,
        replyToEventId: m.replyToEventId,
      );
}
