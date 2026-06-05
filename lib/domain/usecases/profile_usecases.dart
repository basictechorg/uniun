import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

// ── GetProfileUseCase ─────────────────────────────────────────────────────────

@lazySingleton
class GetProfileUseCase
    extends UseCase<Either<Failure, ProfileEntity>, String> {
  final ProfileRepository _repository;
  const GetProfileUseCase(this._repository);

  @override
  Future<Either<Failure, ProfileEntity>> call(
    String pubkey, {
    bool cached = false,
  }) {
    return _repository.getProfile(pubkey);
  }
}

// ── GetOwnProfileUseCase ──────────────────────────────────────────────────────

@lazySingleton
class GetOwnProfileUseCase
    extends UseCase<Either<Failure, ProfileEntity?>, String> {
  final ProfileRepository _repository;
  const GetOwnProfileUseCase(this._repository);

  @override
  Future<Either<Failure, ProfileEntity?>> call(
    String pubkeyHex, {
    bool cached = false,
  }) {
    return _repository.getOwnProfile(pubkeyHex);
  }
}

// ── SaveProfileUseCase ────────────────────────────────────────────────────────

@lazySingleton
class SaveProfileUseCase
    extends UseCase<Either<Failure, ProfileEntity>, ProfileEntity> {
  final ProfileRepository _repository;
  const SaveProfileUseCase(this._repository);

  @override
  Future<Either<Failure, ProfileEntity>> call(
    ProfileEntity profile, {
    bool cached = false,
  }) {
    return _repository.saveProfile(profile);
  }
}

// ── WatchProfileUseCase ───────────────────────────────────────────────────────

@lazySingleton
class WatchProfileUseCase {
  final ProfileRepository _repository;
  const WatchProfileUseCase(this._repository);

  Stream<ProfileEntity?> call(String pubkeyHex) =>
      _repository.watchProfile(pubkeyHex);
}

// ── RequestProfileFetchUseCase ────────────────────────────────────────────────

@lazySingleton
class RequestProfileFetchUseCase
    extends UseCase<Either<Failure, Unit>, String> {
  final ProfileRepository _repository;
  const RequestProfileFetchUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(
    String pubkeyHex, {
    bool cached = false,
  }) {
    return _repository.requestProfileFetch(pubkeyHex);
  }
}

@lazySingleton
class PublishProfileMetadataUseCase
    extends UseCase<Either<Failure, Unit>, ProfileEntity> {
  final EventQueueRepository _eventQueueRepository;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  const PublishProfileMetadataUseCase(
    this._eventQueueRepository,
    this._getActiveUserKeys,
  );

  @override
  Future<Either<Failure, Unit>> call(
    ProfileEntity profile, {
    bool cached = false,
  }) async {
    try {
      final keysResult = await _getActiveUserKeys.call();
      return keysResult.fold((failure) => Left(failure), (keys) async {
        final metadata = <String, dynamic>{
          if (profile.name != null) 'display_name': profile.name,
          if (profile.username != null) 'name': profile.username,
          if (profile.about != null) 'about': profile.about,
          if (profile.avatarUrl != null) 'picture': profile.avatarUrl,
          if (profile.nip05 != null) 'nip05': profile.nip05,
        };

        final event = Event.from(
          privkey: keys.privkeyHex,
          kind: 0,
          content: jsonEncode(metadata),
          tags: const [],
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        final enqueueResult = await _eventQueueRepository.enqueueSignedEvent(
          eventId: event.id,
          authorPubkey: event.pubkey,
          sig: event.sig,
          kind: 0,
          eTagRefs: const [],
          pTagRefs: const [],
          tTags: const [],
          content: event.content,
          created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        );

        return enqueueResult.fold(
          (failure) => Left(failure),
          (_) => const Right(unit),
        );
      });
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
