import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/create_channel_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

class PostReplyParams {
  const PostReplyParams({
    required this.root,
    required this.content,
    this.mentionRefs = const [],
    this.sourceOverride,
  });

  final NoteEntity root;
  final String content;
  final List<String> mentionRefs;

  /// Forces a specific reply transport instead of deriving it from [root].
  /// Used by the saved-only thread, where replies always post as feed notes.
  final NoteSource? sourceOverride;
}

/// Posts a reply to [PostReplyParams.root], routing to the correct transport by
/// the note's [NoteSource]. Every surface sets the same NIP-10 link
/// (`replyToEventId = root.id`, `rootEventId = thread root`); only the encrypted
/// transport differs.
@lazySingleton
class PostReplyUseCase {
  final PublishNoteUseCase _publishNote;
  final CreateChannelMessageUseCase _createChannelMessage;
  final SendPrivateChannelMessageUsecase _sendPrivate;
  final SendDmUseCase _sendDm;
  final GetActiveUserKeysUseCase _getKeys;
  final EmbedAndStoreNoteUseCase _embedAndStore;

  PostReplyUseCase(
    this._publishNote,
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
            final r = await _createChannelMessage.call(CreateChannelMessageInput(
              channelId: root.sourceChannelId ?? '',
              content: params.content,
              privateKey: keys.privkeyHex,
              replyToEventId: replyToId,
              mentionRefs: params.mentionRefs,
            ));
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
            );
            return const Right(unit);

          case NoteSource.dm:
            // The reply goes to the conversation partner: if the root is my own
            // message, that's its receiver; otherwise it's the root's author.
            final counterparty = root.authorPubkey == keys.pubkeyHex
                ? (root.dmReceiverPubkey ?? root.authorPubkey)
                : root.authorPubkey;
            return _sendDm.call(SendDmParams(
              otherPubkey: counterparty,
              content: params.content,
              rootEventId: threadRoot,
              replyToEventId: replyToId,
              mentionRefs: params.mentionRefs,
            ));
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
    final tags = <List<String>>[
      ['e', threadRoot, '', 'root'],
      if (replyToId != threadRoot) ['e', replyToId, '', 'reply'],
      for (final ref in params.mentionRefs) ['e', ref, '', 'mention'],
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
      type: NoteType.text,
      eTagRefs: [
        threadRoot,
        if (replyToId != threadRoot) replyToId,
        ...params.mentionRefs,
      ],
      pTagRefs: const [],
      tTags: const [],
      created: DateTime.fromMillisecondsSinceEpoch(signed.createdAt * 1000),
      isSeen: true,
      rootEventId: threadRoot,
      replyToEventId: replyToId,
    );

    final result = await _publishNote.call(note);
    return result.fold((f) => Left(f), (published) {
      // Fire-and-forget: embed own authored reply for RAG.
      unawaited(_embedAndStore.call((published.id, published.content)));
      return const Right(unit);
    });
  }
}
