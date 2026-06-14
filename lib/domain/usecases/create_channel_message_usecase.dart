import 'dart:convert';

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
import 'package:uniun/domain/repositories/media_repository.dart';

class CreateChannelMessageInput {
  final String channelId;
  final String content;
  final String privateKey;
  final String? replyToEventId;
  final List<String> mentionRefs;
  // NIP-18 quote info — emitted as `["q", id, "", author]` + `["k", kind]`
  // + `["p", author]` tags when [quoteEventId] is set.
  final String? quoteEventId;
  final String? quoteAuthorPubkey;
  final int? quoteKind;

  /// NIP-92 imeta — one tag per attached blob. The use case re-uses the
  /// same `imeta` layout as Brahma so the wire format is identical across
  /// surfaces.
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
class CreateChannelMessageUseCase extends UseCase<Either<Failure, NoteEntity>, CreateChannelMessageInput> {
  final ChannelMessageRepository _channelMessageRepository;
  final EventQueueRepository _eventQueueRepository;
  final MediaRepository _mediaRepository;

  const CreateChannelMessageUseCase(
    this._channelMessageRepository,
    this._eventQueueRepository,
    this._mediaRepository,
  );

  @override
  Future<Either<Failure, NoteEntity>> call(CreateChannelMessageInput input, {bool cached = false}) async {
    try {
      final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Tag order MUST match [EventQueueModelExtension.toSerializedRelayMessage]
      // so the re-serialized broadcast event hashes back to the signed id:
      //   e root → e reply → e mention... → p... → t... → q → k
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
      if (input.quoteEventId != null) {
        tags.add(['q', input.quoteEventId!, '', input.quoteAuthorPubkey ?? '']);
        if (input.quoteKind != null) {
          tags.add(['k', input.quoteKind!.toString()]);
        }
      }
      // imeta tags last — order doesn't affect threading, but the publisher
      // must re-emit in the same order it signed (we send raw-passthrough).
      final imetaTags = buildImetaTags(input.attachments);
      tags.addAll(imetaTags);

      final kind42 = Event.from(
        privkey: input.privateKey,
        kind: 42,
        content: input.content,
        tags: tags,
        createdAt: nowUnix,
      );

      final eTagRefs = <String>[input.channelId];
      if (input.replyToEventId != null) {
        eTagRefs.add(input.replyToEventId!);
      }
      eTagRefs.addAll(input.mentionRefs);

      final created = DateTime.fromMillisecondsSinceEpoch(kind42.createdAt * 1000);

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
      );

      final saveResult = await _channelMessageRepository.saveMessage(message);
      if (saveResult.isLeft()) return saveResult;

      // Link each blob to this note so the gallery + GC see the reference
      // from day one (the inbound handler does the same on receive, but this
      // is the sender side).
      for (final blob in input.attachments) {
        await _mediaRepository.linkNoteRef(
          sha256: blob.sha256,
          noteEventId: kind42.id,
        );
      }

      // When imeta is present the publisher signs the full tag layout; the
      // queue's shaped serializer cannot reproduce imeta byte-for-byte, so
      // we store the entire signed JSON and emit it raw-passthrough.
      final hasImeta = imetaTags.isNotEmpty;
      final fullSignedJson = jsonEncode({
        'id': kind42.id,
        'pubkey': kind42.pubkey,
        'created_at': kind42.createdAt,
        'kind': 42,
        'tags': tags,
        'content': kind42.content,
        'sig': kind42.sig,
      });
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
        content: hasImeta ? fullSignedJson : kind42.content,
        created: created,
        quoteEventId: input.quoteEventId,
        quoteAuthorPubkey: input.quoteAuthorPubkey,
        quoteKind: input.quoteKind,
        rawPassthrough: hasImeta,
      );
      if (enqueueResult.isLeft()) {
        return Left(enqueueResult.fold((f) => f, (_) => const Failure.errorFailure('enqueue failed')));
      }

      return saveResult;
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
