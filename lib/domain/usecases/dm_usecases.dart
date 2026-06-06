import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/utils/pubkey_normalizer.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/dm_conversation_repository.dart';
import 'package:uniun/domain/repositories/dm_message_repository.dart';
import 'package:uniun/domain/services/nip17_encryption_service.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';

class CreateDmParams {
  final String otherPubkey;
  final List<String> relays;

  CreateDmParams({required this.otherPubkey, required this.relays});
}

@lazySingleton
class CreateDmConversationUseCase
    extends UseCase<Either<Failure, DmConversationEntity>, CreateDmParams> {
  final DmConversationRepository _repository;

  CreateDmConversationUseCase(this._repository);

  @override
  Future<Either<Failure, DmConversationEntity>> call(
    CreateDmParams params, {
    bool cached = false,
  }) {
    print("Create Dm usecase called");
    try {
      final normalizedPubkey = normalizeNostrPubkey(params.otherPubkey);
      return _repository.saveConversation(
        DmConversationEntity(
          id: Isar.autoIncrement,
          otherPubkey: normalizedPubkey,
          relays: params.relays,
        ),
      );
    } catch (e) {
      return Future.value(Left(Failure.errorFailure(e.toString())));
    }
  }
}

class SendDmParams {
  final String otherPubkey;
  final String content;
  final NoteType type;
  final String? rootEventId;
  final String? replyToEventId;

  /// Event ids of messages referenced (NIP-10 "mention" e-tags).
  final List<String> mentionRefs;

  SendDmParams({
    required this.otherPubkey,
    required this.content,
    this.type = NoteType.text,
    this.rootEventId,
    this.replyToEventId,
    this.mentionRefs = const [],
  });
}

@lazySingleton
class SendDmUseCase extends UseCase<Either<Failure, Unit>, SendDmParams> {
  final Isar _isar;
  final GetActiveUserKeysUseCase _getKeys;
  final DmConversationRepository _convRepo;

  SendDmUseCase(this._isar, this._getKeys, this._convRepo);

  @override
  Future<Either<Failure, Unit>> call(
    SendDmParams params, {
    bool cached = false,
  }) async {
    print("send dm usecase called");
    try {
      final resolvedOtherPubkey = normalizeNostrPubkey(params.otherPubkey);

      final keysResult = await _getKeys();
      print("keys fetched:" + keysResult.toString());
      return keysResult.fold((failure) => Left(failure), (keys) async {
        // Ensure privkeyHex is raw 32-byte hex (64 chars), never an nsec bech32.
        // GetActiveUserKeysUseCase already calls Nip19.decodePrivkey, so this
        // should already be hex. Guard defensively anyway.
        final privkeyHex = keys.privkeyHex.startsWith('nsec1')
            ? Nip19.decodePrivkey(keys.privkeyHex)
            : keys.privkeyHex;

        final hexRegex = RegExp(r'^[0-9a-fA-F]{64}$');

        if (!hexRegex.hasMatch(privkeyHex)) {
          return Left(
            Failure.errorFailure(
              'Invalid Signer Private Key (Length/Format Exception)',
            ),
          );
        }
        // Resolve Conversation ID natively
        var convResult = await _convRepo.getConversationByOtherPubkey(
          resolvedOtherPubkey,
        );
        if (convResult.isLeft()) {
          // Auto-create if it doesn't exist
          convResult = await _convRepo.saveConversation(
            DmConversationEntity(
              id: Isar.autoIncrement,
              otherPubkey: resolvedOtherPubkey,
              relays: [],
            ),
          );
        }

        return convResult.fold((failure) => Left(failure), (conv) async {
          // Generate a deterministic local ID for outgoing messages.
          // Real eventId will differ from the NIP-01 hash since the
          // Kind-14 payload is unsigned. This avoids Isar unique index
          // violations while keeping the message identifiable.
          final localId = crypto.sha256
              .convert(
                utf8.encode(
                  '${keys.pubkeyHex}:${resolvedOtherPubkey}:${DateTime.now().microsecondsSinceEpoch}',
                ),
              )
              .toString();

          // Spin up a transient encryption service using the decoded privkey hex.
          final service = Nip17EncryptionService(
            _isar,
            NoteRelationRepositoryImpl(isar: _isar),
            privkeyHex: privkeyHex,
          );

          final dm = NoteModel(
            eventId: localId,
            sig: '',
            authorPubkey: keys.pubkeyHex,
            conversationId: conv.id,
            pTagRefs: [resolvedOtherPubkey],
            content: params.content,
            kind: params.type == NoteType.image ? kDmFileKind : kDmTextKind,
            type: params.type,
            tTags: const [],
            created: DateTime.now(),
            rootEventId: params.rootEventId,
            replyToEventId: params.replyToEventId,
            eTagRefs: [
              if (params.rootEventId != null) params.rootEventId!,
              if (params.replyToEventId != null) params.replyToEventId!,
              ...params.mentionRefs,
            ],
          );

          await service.sendDm(dm, receiverPubkey: resolvedOtherPubkey);
          return const Right(unit);
        });
      });
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}

@lazySingleton
class GetDmUseCase extends NoParamsUseCase<Either<Failure, Unit>> {
  final Isar _isar;
  final GetActiveUserKeysUseCase _getKeys;

  GetDmUseCase(this._isar, this._getKeys);

  @override
  Future<Either<Failure, Unit>> call({bool cached = false}) async {
    try {
      print("get dm usecase called");
      final keysResult = await _getKeys();
      return keysResult.fold((f) => Left(f), (keys) async {
        final service = Nip17EncryptionService(
          _isar,
          NoteRelationRepositoryImpl(isar: _isar),
          privkeyHex: keys.privkeyHex,
        );
        await service.processInboundQueue();
        return const Right(unit);
      });
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}

@lazySingleton
class FetchDmUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, String> {
  final DmConversationRepository _convRepo;
  final DmMessageRepository _msgRepo;

  FetchDmUseCase(this._convRepo, this._msgRepo);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    String otherPubkey, {
    bool cached = false,
  }) async {
    print("fetch dm usecase called");
    try {
      final normalizedOtherPubkey = normalizeNostrPubkey(otherPubkey);
      final convResult = await _convRepo.getConversationByOtherPubkey(
        normalizedOtherPubkey,
      );
      return convResult.fold(
        (_) => const Right([]), // Not yet chatting
        (conv) async {
          final messagesResult = await _msgRepo.getMessages(conv.id, limit: 100);
          return messagesResult.fold((f) => Left(f), (msgs) {
            // Re-sort latest first intentionally in dart layer if repo isn't explicitly sorting
            final mutable = List<NoteEntity>.from(msgs);
            mutable.sort((a, b) => b.created.compareTo(a.created));
            return Right(mutable);
          });
        },
      );
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
