import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';
import 'package:uniun/domain/repositories/share_repository.dart';
import 'package:uniun/domain/usecases/create_channel_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

/// One mechanism across every destination: NIP-18 `q` tag.
///
///   - feed (Kind 1) / public channel (Kind 42) → `q` tag rides on the wire,
///     external clients render the quote natively.
///   - DM (Kind 14) / private channel (Kind 9023) → `q` tag rides inside the
///     encrypted payload, opaque to non-members. Same shape.
///
/// `content` carries only the user's optional comment text. The receiver's
/// renderer reads `NoteEntity.quoteEventId`, NOT the content, to decide
/// whether to embed the original.
@Injectable(as: ShareRepository)
class ShareRepositoryImpl implements ShareRepository {
  final NoteResolverRepository _resolver;
  final GetActiveUserKeysUseCase _getKeys;
  final PublishNoteUseCase _publishFeed;
  final CreateChannelMessageUseCase _publishChannel;
  final SendDmUseCase _publishDm;
  final SendPrivateChannelMessageUsecase _publishPrivateChannel;

  ShareRepositoryImpl(
    this._resolver,
    this._getKeys,
    this._publishFeed,
    this._publishChannel,
    this._publishDm,
    this._publishPrivateChannel,
  );

  @override
  Future<Either<Failure, Unit>> shareNote(ShareNoteInput input) async {
    try {
      final sourceResult = await _resolver.resolveById(input.sourceEventId);
      return await sourceResult.fold(
        (f) async => Left(f),
        (source) async {
          final keysResult = await _getKeys();
          return await keysResult.fold(
            (f) async => Left(f),
            (keys) async {
              final comment = input.comment.trim();

              switch (input.destination) {
                case ShareToFeed():
                  return _dispatchFeed(
                    keys: keys,
                    comment: comment,
                    source: source,
                  );
                case ShareToPublicChannel(channelId: final id):
                  return _dispatchChannel(
                    privkey: keys.privkeyHex,
                    channelId: id,
                    comment: comment,
                    source: source,
                  );
                case ShareToPrivateChannel(groupId: final id):
                  return _dispatchPrivateChannel(
                    keys: keys,
                    groupId: id,
                    comment: comment,
                    source: source,
                  );
                case ShareToDm(otherPubkeyHex: final pubkey):
                  return _dispatchDm(
                    otherPubkey: pubkey,
                    comment: comment,
                    source: source,
                  );
              }
            },
          );
        },
      );
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  Future<Either<Failure, Unit>> _dispatchFeed({
    required UserSigningKeys keys,
    required String comment,
    required NoteEntity source,
  }) async {
    // Tag order MUST match EventQueueModel.toSerializedRelayMessage:
    //   e... → p... → t... → q → k
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tags = <List<String>>[
      ['p', source.authorPubkey],
      ['q', source.id, '', source.authorPubkey],
      ['k', source.kind.toString()],
    ];
    final event = Event.from(
      privkey: keys.privkeyHex,
      kind: 1,
      content: comment,
      tags: tags,
      createdAt: nowUnix,
    );
    final entity = NoteEntity(
      id: event.id,
      sig: event.sig,
      authorPubkey: event.pubkey,
      content: event.content,
      kind: kNoteKind,
      type: NoteType.text,
      eTagRefs: const [],
      pTagRefs: [source.authorPubkey],
      tTags: const [],
      created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      quoteEventId: source.id,
    );
    final result = await _publishFeed(
      entity,
      quoteAuthorPubkey: source.authorPubkey,
      quoteKind: source.kind,
    );
    return result.fold((f) => Left(f), (_) => const Right(unit));
  }

  Future<Either<Failure, Unit>> _dispatchChannel({
    required String privkey,
    required String channelId,
    required String comment,
    required NoteEntity source,
  }) async {
    final result = await _publishChannel(
      CreateChannelMessageInput(
        channelId: channelId,
        content: comment,
        privateKey: privkey,
        quoteEventId: source.id,
        quoteAuthorPubkey: source.authorPubkey,
        quoteKind: source.kind,
      ),
    );
    return result.fold((f) => Left(f), (_) => const Right(unit));
  }

  Future<Either<Failure, Unit>> _dispatchPrivateChannel({
    required UserSigningKeys keys,
    required String groupId,
    required String comment,
    required NoteEntity source,
  }) async {
    await _publishPrivateChannel.execute(
      groupId: groupId,
      content: comment,
      authorPubkey: keys.pubkeyHex,
      privkeyHex: keys.privkeyHex,
      quoteEventId: source.id,
    );
    return const Right(unit);
  }

  Future<Either<Failure, Unit>> _dispatchDm({
    required String otherPubkey,
    required String comment,
    required NoteEntity source,
  }) async {
    final result = await _publishDm(
      SendDmParams(
        otherPubkey: otherPubkey,
        content: comment,
        quoteEventId: source.id,
        quoteAuthorPubkey: source.authorPubkey,
        quoteKind: source.kind,
      ),
    );
    return result.fold((f) => Left(f), (_) => const Right(unit));
  }
}
