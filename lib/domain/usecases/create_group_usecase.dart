import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/repositories/group_repository.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';

class CreateGroupInput {
  final String name;
  final String about;
  final String picture;
  final List<String> relays;
  final String privateKey;

  const CreateGroupInput({
    required this.name,
    required this.about,
    required this.picture,
    required this.relays,
    required this.privateKey,
  });
}

/// Creates a NIP-28 group locally and enqueues kind **40** for relay publish.
/// [GroupModel] presence implies the user is subscribed to that group.
@lazySingleton
class CreateGroupUseCase
    extends UseCase<Either<Failure, GroupEntity>, CreateGroupInput> {
  final GroupRepository _groupRepository;
  final EventQueueRepository _eventQueueRepository;

  const CreateGroupUseCase(
    this._groupRepository,
    this._eventQueueRepository,
  );

  @override
  Future<Either<Failure, GroupEntity>> call(
    CreateGroupInput input, {
    bool cached = false,
  }) async {
    try {
      final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final metadata = {
        'name': input.name,
        'about': input.about,
        'picture': input.picture,
      };

      final kind40 = Event.from(
        privkey: input.privateKey,
        kind: 40,
        content: jsonEncode(metadata),
        tags: const [],
        createdAt: nowUnix,
      );

      // NIP-28: the group's unique id is the hex event id of this kind-40 event.
      final groupId = kind40.id;

      final group = GroupEntity(
        groupId: groupId,
        creatorPubKey: kind40.pubkey,
        name: input.name,
        about: input.about,
        picture: input.picture,
        relays: input.relays,
        createdAt: nowUnix,
        updatedAt: nowUnix,
      );

      final saveResult = await _groupRepository.saveGroup(group);
      if (saveResult.isLeft()) return saveResult;

      final created = DateTime.fromMillisecondsSinceEpoch(
        kind40.createdAt * 1000,
      );
      final enqueueResult = await _eventQueueRepository.enqueueSignedEvent(
        eventId: groupId,
        authorPubkey: kind40.pubkey,
        sig: kind40.sig,
        kind: 40,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        content: kind40.content,
        created: created,
      );
      if (enqueueResult.isLeft()) {
        return Left(
          enqueueResult.fold(
            (f) => f,
            (_) => const Failure.errorFailure('enqueue failed'),
          ),
        );
      }

      return saveResult;
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
