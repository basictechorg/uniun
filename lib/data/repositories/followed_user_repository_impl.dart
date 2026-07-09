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
import 'package:uniun/features/mesh/sync/bodies/followed_user_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';

@Injectable(as: FollowedUserRepository)
class FollowedUserRepositoryImpl extends FollowedUserRepository {
  final Isar _isar;
  final EventQueueRepository _eventQueue;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  FollowedUserRepositoryImpl({
    required Isar isar,
    required EventQueueRepository eventQueue,
    required GetActiveUserKeysUseCase getActiveUserKeys,
  }) : _isar = isar,
       _eventQueue = eventQueue,
       _getActiveUserKeys = getActiveUserKeys;

  @override
  Future<Either<Failure, Unit>> followUser(
    String pubkeyHex, {
    String? relayHint,
    String? petname,
  }) async {
    final keysResult = await _getActiveUserKeys.call();
    return keysResult.fold(Left.new, (keys) async {
      try {
        final now = DateTime.now();
        final existing = await _isar.followedUserModels
            .where()
            .pubkeyHexEqualTo(pubkeyHex)
            .findFirst();
        final row = existing ?? FollowedUserModel();
        row.pubkeyHex = pubkeyHex;
        row.relayHint = relayHint ?? row.relayHint;
        row.petname = petname ?? row.petname;
        row.followedAt = existing?.followedAt ?? now;
        row.removedAt = null;
        row.signedNostrEvent = await _signFollowedUser(
          row,
          privkeyHex: keys.privkeyHex,
          pubkeyHex: keys.pubkeyHex,
          removed: false,
        );
        await _isar.writeTxn(() async {
          await _isar.followedUserModels.put(row);
        });
        return _publishContactListWithKeys(privkeyHex: keys.privkeyHex);
      } catch (e) {
        return Left(Failure.errorFailure(e.toString()));
      }
    });
  }

  @override
  Future<Either<Failure, Unit>> followUsers(List<String> pubkeyHexes) async {
    final keysResult = await _getActiveUserKeys.call();
    return keysResult.fold(Left.new, (keys) async {
      try {
        final now = DateTime.now();
        final existingRows = await _isar.followedUserModels.where().findAll();
        final existingByPubkey = {for (final r in existingRows) r.pubkeyHex: r};
        final updates = <FollowedUserModel>[];
        for (final pubkey in pubkeyHexes) {
          final existing = existingByPubkey[pubkey];
          if (existing != null && existing.removedAt == null) continue;
          final row = existing ?? FollowedUserModel();
          row.pubkeyHex = pubkey;
          row.followedAt = existing?.followedAt ?? now;
          row.removedAt = null;
          row.signedNostrEvent = await _signFollowedUser(
            row,
            privkeyHex: keys.privkeyHex,
            pubkeyHex: keys.pubkeyHex,
            removed: false,
          );
          updates.add(row);
        }
        if (updates.isNotEmpty) {
          await _isar.writeTxn(() async {
            await _isar.followedUserModels.putAll(updates);
          });
        }
        // Publish the merged contact list exactly once for the whole batch.
        return _publishContactListWithKeys(privkeyHex: keys.privkeyHex);
      } catch (e) {
        return Left(Failure.errorFailure(e.toString()));
      }
    });
  }

  @override
  Future<Either<Failure, Unit>> unfollowUser(String pubkeyHex) async {
    final keysResult = await _getActiveUserKeys.call();
    return keysResult.fold(Left.new, (keys) async {
      try {
        final now = DateTime.now();
        final existing = await _isar.followedUserModels
            .where()
            .pubkeyHexEqualTo(pubkeyHex)
            .findFirst();
        final row = existing ?? FollowedUserModel();
        row.pubkeyHex = pubkeyHex;
        row.followedAt = existing?.followedAt ?? now;
        row.removedAt = now;
        row.signedNostrEvent = await _signFollowedUser(
          row,
          privkeyHex: keys.privkeyHex,
          pubkeyHex: keys.pubkeyHex,
          removed: true,
        );
        await _isar.writeTxn(() async {
          await _isar.followedUserModels.put(row);
        });
        return _publishContactListWithKeys(privkeyHex: keys.privkeyHex);
      } catch (e) {
        return Left(Failure.errorFailure(e.toString()));
      }
    });
  }

  @override
  Future<Either<Failure, bool>> isFollowing(String pubkeyHex) async {
    try {
      final hit = await _isar.followedUserModels
          .where()
          .pubkeyHexEqualTo(pubkeyHex)
          .findFirst();
      return Right(hit != null && hit.removedAt == null);
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
      return Right(
        rows
            .where((m) => m.removedAt == null)
            .map((m) => m.toDomain())
            .toList(),
      );
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAllPubkeys() async {
    try {
      final rows = await _isar.followedUserModels.where().findAll();
      return Right(
        rows.where((m) => m.removedAt == null).map((m) => m.pubkeyHex).toList(),
      );
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
    return rows
        .where((m) => m.removedAt == null)
        .map((m) => m.toDomain())
        .toList();
  }

  Future<Either<Failure, Unit>> _publishContactListWithKeys({
    required String privkeyHex,
  }) async {
    try {
      final rows = (await _isar.followedUserModels.where().findAll())
          .where((r) => r.removedAt == null)
          .toList();
      // NIP-02 allows omitting relay / petname; the outbound serializer
      // (EventQueueModel.toSerializedRelayMessage) emits 2-tuple p-tags, so
      // we must sign over the same shape or the relay rejects the signature.
      final tags = <List<String>>[
        for (final r in rows) ['p', r.pubkeyHex],
      ];

      final event = Event.from(
        privkey: privkeyHex,
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
  }

  Future<String> _signFollowedUser(
    FollowedUserModel row, {
    required String privkeyHex,
    required String pubkeyHex,
    required bool removed,
  }) {
    final codec = MeshEventCodec(privkeyHex: privkeyHex, pubkeyHex: pubkeyHex);
    return codec.signRecord(
      kind: MeshEventKinds.followedUser,
      dTag: row.pubkeyHex,
      content: removed
          ? FollowedUserBody.forRemoved(row)
          : FollowedUserBody.forActive(row),
    );
  }
}
