import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/followed_user_repository.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

@Injectable(as: FollowedUserRepository)
class FollowedUserRepositoryImpl extends FollowedUserRepository {
  final Isar _isar;
  final EventQueueRepository _eventQueue;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  FollowedUserRepositoryImpl({
    required Isar isar,
    required EventQueueRepository eventQueue,
    required GetActiveUserKeysUseCase getActiveUserKeys,
  })  : _isar = isar,
        _eventQueue = eventQueue,
        _getActiveUserKeys = getActiveUserKeys;

  @override
  Future<Either<Failure, Unit>> followUser(
    String pubkeyHex, {
    String? relayHint,
    String? petname,
  }) async {
    try {
      final existing = await _isar.followedUserModels
          .where()
          .pubkeyHexEqualTo(pubkeyHex)
          .findFirst();
      if (existing == null) {
        await _isar.writeTxn(() async {
          await _isar.followedUserModels.put(
            FollowedUserModel()
              ..pubkeyHex = pubkeyHex
              ..relayHint = relayHint
              ..petname = petname
              ..followedAt = DateTime.now(),
          );
        });
      }
      return _publishContactList();
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> unfollowUser(String pubkeyHex) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.followedUserModels
            .where()
            .pubkeyHexEqualTo(pubkeyHex)
            .deleteAll();
      });
      return _publishContactList();
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isFollowing(String pubkeyHex) async {
    try {
      final hit = await _isar.followedUserModels
          .where()
          .pubkeyHexEqualTo(pubkeyHex)
          .findFirst();
      return Right(hit != null);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FollowedUserEntity>>> getAll() async {
    try {
      final rows = await _isar.followedUserModels
          .where()
          .sortByFollowedAtDesc()
          .findAll();
      return Right(rows.map((m) => m.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAllPubkeys() async {
    try {
      final rows = await _isar.followedUserModels.where().findAll();
      return Right(rows.map((m) => m.pubkeyHex).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Stream<List<FollowedUserEntity>> watchFollowed() async* {
    yield await _readAll();
    await for (final _ in _isar.followedUserModels.watchLazy()) {
      yield await _readAll();
    }
  }

  Future<List<FollowedUserEntity>> _readAll() async {
    final rows = await _isar.followedUserModels
        .where()
        .sortByFollowedAtDesc()
        .findAll();
    return rows.map((m) => m.toDomain()).toList();
  }

  Future<Either<Failure, Unit>> _publishContactList() async {
    final keysResult = await _getActiveUserKeys.call();
    return keysResult.fold(Left.new, (keys) async {
      try {
        final rows = await _isar.followedUserModels.where().findAll();
        // NIP-02 allows omitting relay / petname; the outbound serializer
        // (EventQueueModel.toSerializedRelayMessage) emits 2-tuple p-tags, so
        // we must sign over the same shape or the relay rejects the signature.
        final tags = <List<String>>[
          for (final r in rows) ['p', r.pubkeyHex],
        ];

        final event = Event.from(
          privkey: keys.privkeyHex,
          kind: 3,
          content: '',
          tags: tags,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        final enqueue = await _eventQueue.enqueueSignedEvent(
          eventId: event.id,
          authorPubkey: event.pubkey,
          sig: event.sig,
          kind: 3,
          eTagRefs: const [],
          pTagRefs: rows.map((r) => r.pubkeyHex).toList(),
          tTags: const [],
          content: event.content,
          created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        );

        return enqueue.fold(Left.new, (_) => const Right(unit));
      } catch (e) {
        return Left(Failure.errorFailure(e.toString()));
      }
    });
  }
}
