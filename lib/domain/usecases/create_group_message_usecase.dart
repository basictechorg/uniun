import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/group_message_repository.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';

class CreateGroupMessageInput {
  final String groupId;
  final String content;
  final String privateKey;
  final String? replyToEventId;
  final List<String> mentionRefs;

  /// Embed-by-value share snapshot → the `embeddedNoteJson` tag. Null when this
  /// message quotes nothing.
  final String? embeddedNoteJson;

  /// NIP-92 imeta — one tag per attached blob.
  final List<MediaBlobEntity> attachments;

  const CreateGroupMessageInput({
    required this.groupId,
    required this.content,
    required this.privateKey,
    this.replyToEventId,
    this.mentionRefs = const [],
    this.embeddedNoteJson,
    this.attachments = const [],
  });
}

@lazySingleton
class CreateGroupMessageUseCase
    extends UseCase<Either<Failure, NoteEntity>, CreateGroupMessageInput> {
  final GroupMessageRepository _groupMessageRepository;
  final EventQueueRepository _eventQueueRepository;

  const CreateGroupMessageUseCase(
    this._groupMessageRepository,
    this._eventQueueRepository,
  );

  @override
  Future<Either<Failure, NoteEntity>> call(
    CreateGroupMessageInput input, {
    bool cached = false,
  }) async {
    try {
      final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Tag order MUST match
      // [EventQueueModelExtension.toSerializedRelayMessage]:
      //   e root → e reply → e mention → embeddedNoteJson → imeta
      final tags = <List<String>>[
        ['e', input.groupId, '', 'root'],
      ];
      if (input.replyToEventId != null) {
        tags.add(['e', input.replyToEventId!, '', 'reply']);
      }
      for (final ref in input.mentionRefs) {
        tags.add(['e', ref, '', 'mention']);
      }
      if (input.embeddedNoteJson != null) {
        tags.add(EmbeddedNoteCodec.tag(input.embeddedNoteJson!));
      }
      tags.addAll(buildImetaTags(input.attachments));

      final kind42 = Event.from(
        privkey: input.privateKey,
        kind: 42,
        content: input.content,
        tags: tags,
        createdAt: nowUnix,
      );

      final eTagRefs = <String>[input.groupId];
      if (input.replyToEventId != null) eTagRefs.add(input.replyToEventId!);
      eTagRefs.addAll(input.mentionRefs);

      final created =
          DateTime.fromMillisecondsSinceEpoch(kind42.createdAt * 1000);

      final message = NoteEntity(
        id: kind42.id,
        sig: kind42.sig,
        authorPubkey: kind42.pubkey,
        content: kind42.content,
        kind: kGroupMessageKind,
        sourceGroupId: input.groupId,
        type: NoteType.text,
        eTagRefs: eTagRefs,
        pTagRefs: const [],
        tTags: const [],
        rootEventId: input.groupId,
        replyToEventId: input.replyToEventId,
        created: created,
        embeddedNoteJson: input.embeddedNoteJson,
        attachments: input.attachments,
      );

      final saveResult = await _groupMessageRepository.saveMessage(message);
      if (saveResult.isLeft()) return saveResult;

      final enqueueResult = await _eventQueueRepository.enqueueSignedEvent(
        eventId: kind42.id,
        authorPubkey: kind42.pubkey,
        sig: kind42.sig,
        kind: 42,
        eTagRefs: eTagRefs,
        pTagRefs: const [],
        tTags: const [],
        rootEventId: input.groupId,
        replyToEventId: input.replyToEventId,
        content: kind42.content,
        created: created,
        embeddedNoteJson: input.embeddedNoteJson,
        imeta: input.attachments,
      );
      if (enqueueResult.isLeft()) {
        return Left(enqueueResult.fold(
            (f) => f, (_) => const Failure.errorFailure('enqueue failed')));
      }

      return saveResult;
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
