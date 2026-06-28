import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_join_request_entity.dart';
import 'package:uniun/domain/repositories/e2ee_group_repository.dart';
import 'package:uniun/domain/services/marmot_transport_service.dart';

@lazySingleton
class CreatePrivateGroupUsecase {
  final MarmotTransportService transportService;
  CreatePrivateGroupUsecase(this.transportService);

  Future<String> execute({
    required String privkeyHex,
    required String authorPubkey,
    required String name,
    required String description,
    required List<String> relays,
  }) async {
    return await transportService.createGroup(
      privkeyHex: privkeyHex,
      authorPubkey: authorPubkey,
      name: name,
      description: description,
      relays: relays,
    );
  }
}

@lazySingleton
class GetPrivateGroupsUsecase {
  final E2EEGroupRepository repository;
  GetPrivateGroupsUsecase(this.repository);

  Stream<List<PrivateGroupEntity>> execute() {
    return repository.watchGroups();
  }
}

@lazySingleton
class GetPrivateGroupEntityUsecase {
  final E2EEGroupRepository repository;
  GetPrivateGroupEntityUsecase(this.repository);

  Future<PrivateGroupEntity?> execute(String groupId) async {
    final groups = await repository.watchGroups().first;
    try {
      return groups.firstWhere((c) => c.groupId == groupId);
    } catch (_) {
      return null;
    }
  }

  /// Reactive variant: emits the group each time it changes (e.g. when the
  /// MLS Welcome arrives and populates [PrivateGroupEntity.mlsGroupId]).
  Stream<PrivateGroupEntity?> watch(String groupId) {
    return repository.watchGroups().map((groups) {
      for (final c in groups) {
        if (c.groupId == groupId) return c;
      }
      return null;
    });
  }
}

@lazySingleton
class GetPrivateGroupMessagesUsecase {
  final E2EEGroupRepository repository;
  GetPrivateGroupMessagesUsecase(this.repository);

  Stream<List<NoteEntity>> execute(String groupId) {
    return repository.watchMessages(groupId);
  }
}

@lazySingleton
class GetPrivateGroupJoinRequestsUsecase {
  final E2EEGroupRepository repository;
  GetPrivateGroupJoinRequestsUsecase(this.repository);

  Stream<List<PrivateGroupJoinRequestEntity>> execute(String groupId) {
    return repository.watchJoinRequests(groupId);
  }
}

@lazySingleton
class SendPrivateGroupMessageUsecase {
  final MarmotTransportService transportService;
  SendPrivateGroupMessageUsecase(this.transportService);

  Future<void> execute({
    required String groupId,
    required String content,
    required String authorPubkey,
    required String privkeyHex,
    List<String> mentionRefs = const [],
    String? rootEventId,
    String? replyToEventId,
    String? embeddedNoteJson,
    List<MediaBlobEntity> attachments = const [],
  }) async {
    await transportService.sendGroupMessage(
      groupId: groupId,
      content: content,
      authorPubkey: authorPubkey,
      privkeyHex: privkeyHex,
      mentionRefs: mentionRefs,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      embeddedNoteJson: embeddedNoteJson,
      attachments: attachments,
    );
  }
}

@lazySingleton
class JoinPrivateGroupUsecase {
  final MarmotTransportService transportService;
  JoinPrivateGroupUsecase(this.transportService);

  Future<void> execute({
    required String groupId,
    required String authorPubkey,
    required String privkeyHex,
    required List<String> relays,
  }) async {
    await transportService.joinGroup(
      groupId: groupId,
      authorPubkey: authorPubkey,
      privkeyHex: privkeyHex,
      relays: relays,
    );
  }
}

@lazySingleton
class ApprovePrivateGroupJoinUsecase {
  final MarmotTransportService transportService;
  ApprovePrivateGroupJoinUsecase(this.transportService);

  Future<void> execute({
    required String groupId,
    required String userKeyPackageB64,
    required String adminPrivkeyHex,
  }) async {
    await transportService.approveJoinRequest(
      groupId: groupId,
      userKeyPackageB64: userKeyPackageB64,
      adminPrivkeyHex: adminPrivkeyHex,
    );
  }
}

@lazySingleton
class LeavePrivateGroupUsecase {
  final MarmotTransportService transportService;
  LeavePrivateGroupUsecase(this.transportService);

  Future<void> execute({
    required String groupId,
    required String authorPubkey,
    required String privkeyHex,
  }) async {
    await transportService.leaveGroup(
      groupId: groupId,
      authorPubkey: authorPubkey,
      privkeyHex: privkeyHex,
    );
  }
}
