import 'dart:async';
import 'dart:convert';

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

  /// Uploaded Blossom blobs. Emitted as NIP-92 `imeta` tags on the outbound
  /// event (feed/channel) or carried inside the encrypted envelope (DM and
  /// private channel — receiver-side rendering of those is pending).
  final List<MediaBlobEntity> attachments;

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
            final r = await _createChannelMessage.call(CreateChannelMessageInput(
              channelId: root.sourceChannelId ?? '',
              content: params.content,
              privateKey: keys.privkeyHex,
              replyToEventId: replyToId,
              mentionRefs: params.mentionRefs,
              attachments: params.attachments,
            ));
            return r.fold((f) => Left(f), (_) => const Right(unit));

          case NoteSource.privateChannel:
            // TODO: encrypted-envelope imeta for receiver-side render. The
            // attachments upload + own-side render works (NoteMediaRefModel
            // is written by the composer flow) but the encrypted body has
            // no imeta field yet.
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
            // TODO: imeta inside the NIP-17 rumor before encryption + receiver
            // decrypt path to populate MediaBlobModel. Same status as
            // privateChannel above.
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
    final imetaTags = buildImetaTags(params.attachments);
    final tags = <List<String>>[
      ['e', threadRoot, '', 'root'],
      if (replyToId != threadRoot) ['e', replyToId, '', 'reply'],
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
      type: imetaTags.isEmpty ? NoteType.text : NoteType.image,
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
    );

    // Media replies need the rawPassthrough path so the imeta tag order
    // survives serialization and the broadcast event re-hashes back to id.
    final Either<Failure, NoteEntity> result;
    if (imetaTags.isEmpty) {
      result = await _publishNote.call(note);
    } else {
      final fullSignedJson = jsonEncode({
        'id': signed.id,
        'pubkey': pubkeyHex,
        'created_at': signed.createdAt,
        'kind': 1,
        'tags': tags,
        'content': signed.content,
        'sig': signed.sig,
      });
      result = await _publishMediaNote.call(PublishMediaNoteInput(
        note: note,
        fullSignedJson: fullSignedJson,
        attachedShas:
            params.attachments.map((b) => b.sha256).toList(growable: false),
      ));
    }
    return result.fold((f) => Left(f), (published) {
      unawaited(_embedAndStore.call((published.id, published.content)));
      return const Right(unit);
    });
  }
}
