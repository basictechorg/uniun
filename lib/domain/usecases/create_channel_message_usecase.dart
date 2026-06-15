import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/channel_message_repository.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';

class CreateChannelMessageInput {
  final String channelId;
  final String content;
  final String privateKey;
  final String? replyToEventId;
  final List<String> mentionRefs;
  // NIP-18 quote — `["q", id, "", author]` + `["k", kind]` + `["p", author]`.
  final String? quoteEventId;
  final String? quoteAuthorPubkey;
  final int? quoteKind;

  /// NIP-92 imeta — one tag per attached blob.
  final List<MediaBlobEntity> attachments;

  const CreateChannelMessageInput({
    required this.channelId,
    required this.content,
    required this.privateKey,
    this.replyToEventId,
    this.mentionRefs = const [],
    this.quoteEventId,
    this.quoteAuthorPubkey,
    this.quoteKind,
    this.attachments = const [],
  });
}

@lazySingleton
class CreateChannelMessageUseCase
    extends UseCase<Either<Failure, NoteEntity>, CreateChannelMessageInput> {
  final ChannelMessageRepository _channelMessageRepository;
  final EventQueueRepository _eventQueueRepository;

  const CreateChannelMessageUseCase(
    this._channelMessageRepository,
    this._eventQueueRepository,
  );

  @override
  Future<Either<Failure, NoteEntity>> call(
    CreateChannelMessageInput input, {
    bool cached = false,
  }) async {
    try {
      final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Tag order MUST match
      // [EventQueueModelExtension.toSerializedRelayMessage]:
      //   e root → e reply → e mention → p → t → k → q → imeta
      final tags = <List<String>>[
        ['e', input.channelId, '', 'root'],
      ];
      if (input.replyToEventId != null) {
        tags.add(['e', input.replyToEventId!, '', 'reply']);
      }
      for (final ref in input.mentionRefs) {
        tags.add(['e', ref, '', 'mention']);
      }
      if (input.quoteEventId != null && input.quoteAuthorPubkey != null) {
        tags.add(['p', input.quoteAuthorPubkey!]);
      }
      if (input.quoteKind != null) {
        tags.add(['k', input.quoteKind!.toString()]);
      }
      if (input.quoteEventId != null) {
        tags.add(['q', input.quoteEventId!, '', input.quoteAuthorPubkey ?? '']);
      }
      tags.addAll(buildImetaTags(input.attachments));

      final kind42 = Event.from(
        privkey: input.privateKey,
        kind: 42,
        content: input.content,
        tags: tags,
        createdAt: nowUnix,
      );

      final eTagRefs = <String>[input.channelId];
      if (input.replyToEventId != null) eTagRefs.add(input.replyToEventId!);
      eTagRefs.addAll(input.mentionRefs);

      final created =
          DateTime.fromMillisecondsSinceEpoch(kind42.createdAt * 1000);

      final message = NoteEntity(
        id: kind42.id,
        sig: kind42.sig,
        authorPubkey: kind42.pubkey,
        content: kind42.content,
        kind: kChannelMessageKind,
        sourceChannelId: input.channelId,
        type: NoteType.text,
        eTagRefs: eTagRefs,
        pTagRefs: const [],
        tTags: const [],
        rootEventId: input.channelId,
        replyToEventId: input.replyToEventId,
        created: created,
        quoteEventId: input.quoteEventId,
        hasMedia: input.attachments.isNotEmpty,
        attachments: input.attachments,
      );

      final saveResult = await _channelMessageRepository.saveMessage(message);
      if (saveResult.isLeft()) return saveResult;

      final enqueueResult = await _eventQueueRepository.enqueueSignedEvent(
        eventId: kind42.id,
        authorPubkey: kind42.pubkey,
        sig: kind42.sig,
        kind: 42,
        eTagRefs: eTagRefs,
        pTagRefs: input.quoteAuthorPubkey != null && input.quoteEventId != null
            ? [input.quoteAuthorPubkey!]
            : const [],
        tTags: const [],
        rootEventId: input.channelId,
        replyToEventId: input.replyToEventId,
        content: kind42.content,
        created: created,
        quoteEventId: input.quoteEventId,
        quoteAuthorPubkey: input.quoteAuthorPubkey,
        quoteKind: input.quoteKind,
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
