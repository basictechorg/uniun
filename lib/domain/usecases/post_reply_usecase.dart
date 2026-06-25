import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/create_channel_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

class PostReplyParams {
  const PostReplyParams({
    required this.root,
    required this.content,
    this.mentionRefs = const [],
    this.attachments = const [],
    this.sourceOverride,
  });

  final NoteEntity root;
  final String content;
  final List<String> mentionRefs;

  final List<MediaBlobEntity> attachments;

  final NoteSource? sourceOverride;
}

@lazySingleton
class PostReplyUseCase {
  final PublishNoteUseCase _publishNote;
  final PublishMediaNoteUseCase _publishMediaNote;
  final CreateChannelMessageUseCase _createChannelMessage;
  final SendPrivateChannelMessageUsecase _sendPrivate;
  final SendDmUseCase _sendDm;
  final GetActiveUserKeysUseCase _getKeys;
  final EmbedAndStoreNoteUseCase _embedAndStore;

  PostReplyUseCase(
    this._publishNote,
    this._publishMediaNote,
    this._createChannelMessage,
    this._sendPrivate,
    this._sendDm,
    this._getKeys,
    this._embedAndStore,
  );

  Future<Either<Failure, Unit>> call(PostReplyParams params) async {
    final root = params.root;
    final replyToId = root.id;
    final threadRoot = root.rootEventId ?? root.id;
    final source = params.sourceOverride ?? root.replyTransport;

    final keysResult = await _getKeys();
    return keysResult.fold((f) => Left(f), (keys) async {
      try {
        switch (source) {
          case NoteSource.feed:
            return _replyToFeed(
              privkeyHex: keys.privkeyHex,
              pubkeyHex: keys.pubkeyHex,
              replyToId: replyToId,
              threadRoot: threadRoot,
              params: params,
            );

          case NoteSource.channel:
            final r = await _createChannelMessage.call(
              CreateChannelMessageInput(
                channelId: root.sourceChannelId ?? '',
                content: params.content,
                privateKey: keys.privkeyHex,
                replyToEventId: replyToId,
                mentionRefs: params.mentionRefs,
                attachments: params.attachments,
              ),
            );
            return r.fold((f) => Left(f), (_) => const Right(unit));

          case NoteSource.privateChannel:
            await _sendPrivate.execute(
              groupId: root.sourcePrivateGroupId ?? '',
              content: params.content,
              authorPubkey: keys.pubkeyHex,
              privkeyHex: keys.privkeyHex,
              mentionRefs: params.mentionRefs,
              rootEventId: threadRoot,
              replyToEventId: replyToId,
              attachments: params.attachments,
            );
            return const Right(unit);

          case NoteSource.dm:
            final counterparty = root.authorPubkey == keys.pubkeyHex
                ? (root.dmReceiverPubkey ?? root.authorPubkey)
                : root.authorPubkey;
            return _sendDm.call(
              SendDmParams(
                otherPubkey: counterparty,
                content: params.content,
                type: params.attachments.any((a) => a.mime.startsWith('image/'))
                    ? NoteType.image
                    : NoteType.text,
                rootEventId: threadRoot,
                replyToEventId: replyToId,
                mentionRefs: params.mentionRefs,
                attachments: params.attachments,
              ),
            );
        }
      } catch (e) {
        return Left(Failure.errorFailure(e.toString()));
      }
    });
  }

  Future<Either<Failure, Unit>> _replyToFeed({
    required String privkeyHex,
    required String pubkeyHex,
    required String replyToId,
    required String threadRoot,
    required PostReplyParams params,
  }) async {
    // Tag order MUST match [EventQueueModel.toSerializedRelayMessage].
    // Reply marker is always emitted (even when replyToId == threadRoot)
    // because UNIUN's thread BFS keys on `replyToEventId` — see #76.
    final imetaTags = buildImetaTags(params.attachments);
    final tags = <List<String>>[
      ['e', threadRoot, '', 'root'],
      ['e', replyToId, '', 'reply'],
      for (final ref in params.mentionRefs) ['e', ref, '', 'mention'],
      ...imetaTags,
    ];

    late final Event signed;
    try {
      signed = Event.from(
        kind: 1,
        tags: tags,
        content: params.content.trim(),
        privkey: privkeyHex,
      );
    } catch (e) {
      return Left(Failure.errorFailure('Signing failed: $e'));
    }

    final note = NoteEntity(
      id: signed.id,
      sig: signed.sig,
      authorPubkey: pubkeyHex,
      content: signed.content,
      type: params.attachments.isEmpty ? NoteType.text : NoteType.image,
      eTagRefs: [
        threadRoot,
        if (replyToId != threadRoot) replyToId,
        ...params.mentionRefs,
      ],
      pTagRefs: const [],
      tTags: const [],
      created: DateTime.fromMillisecondsSinceEpoch(signed.createdAt * 1000),
      rootEventId: threadRoot,
      replyToEventId: replyToId,
      attachments: params.attachments,
    );

    final result = params.attachments.isEmpty
        ? await _publishNote.call(note)
        : await _publishMediaNote.call(
            PublishMediaNoteInput(note: note, attachments: params.attachments),
          );
    return result.fold((f) => Left(f), (published) {
      unawaited(_embedAndStore.call((published.id, published.content)));
      return const Right(unit);
    });
  }
}
