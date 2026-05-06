import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/private_channel_entity.dart';
import 'package:uniun/domain/entities/private_channel_message_entity.dart';
import 'package:uniun/domain/entities/private_channel_join_request_entity.dart';
import 'package:uniun/domain/repositories/e2ee_group_repository.dart';
import 'package:uniun/domain/services/marmot_transport_service.dart';

@lazySingleton
class CreatePrivateChannelUsecase {
  final MarmotTransportService transportService;
  CreatePrivateChannelUsecase(this.transportService);

  Future<String> execute({
    required String privkeyHex,
    required String authorPubkey,
    required String name,
    required String description,
    required List<String> relays,
  }) async {
    return await transportService.createChannel(
      privkeyHex: privkeyHex,
      authorPubkey: authorPubkey,
      name: name,
      description: description,
      relays: relays,
    );
  }
}

@lazySingleton
class GetPrivateChannelsUsecase {
  final E2EEGroupRepository repository;
  GetPrivateChannelsUsecase(this.repository);

  Stream<List<PrivateChannelEntity>> execute() {
    return repository.watchChannels();
  }
}

@lazySingleton
class GetPrivateChannelEntityUsecase {
  final E2EEGroupRepository repository;
  GetPrivateChannelEntityUsecase(this.repository);

  Future<PrivateChannelEntity?> execute(String groupId) async {
    final channels = await repository.watchChannels().first;
    try {
      return channels.firstWhere((c) => c.groupId == groupId);
    } catch (_) {
      return null;
    }
  }
}

@lazySingleton
class GetPrivateChannelMessagesUsecase {
  final E2EEGroupRepository repository;
  GetPrivateChannelMessagesUsecase(this.repository);

  Stream<List<PrivateChannelMessageEntity>> execute(String groupId) {
    return repository.watchMessages(groupId);
  }
}

@lazySingleton
class GetPrivateChannelJoinRequestsUsecase {
  final E2EEGroupRepository repository;
  GetPrivateChannelJoinRequestsUsecase(this.repository);

  Stream<List<PrivateChannelJoinRequestEntity>> execute(String groupId) {
    return repository.watchJoinRequests(groupId);
  }
}

@lazySingleton
class SendPrivateChannelMessageUsecase {
  final MarmotTransportService transportService;
  SendPrivateChannelMessageUsecase(this.transportService);

  Future<void> execute({
    required String groupId,
    required String content,
    required String authorPubkey,
    required String privkeyHex,
  }) async {
    await transportService.sendChannelMessage(
      groupId: groupId,
      content: content,
      authorPubkey: authorPubkey,
      privkeyHex: privkeyHex,
    );
  }
}

@lazySingleton
class JoinPrivateChannelUsecase {
  final MarmotTransportService transportService;
  JoinPrivateChannelUsecase(this.transportService);

  Future<void> execute({
    required String groupId,
    required String authorPubkey,
    required String privkeyHex,
    required List<String> relays,
  }) async {
    await transportService.joinChannel(
      groupId: groupId,
      authorPubkey: authorPubkey,
      privkeyHex: privkeyHex,
      relays: relays,
    );
  }
}

@lazySingleton
class ApprovePrivateChannelJoinUsecase {
  final MarmotTransportService transportService;
  ApprovePrivateChannelJoinUsecase(this.transportService);

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
class LeavePrivateChannelUsecase {
  final MarmotTransportService transportService;
  LeavePrivateChannelUsecase(this.transportService);

  Future<void> execute({
    required String groupId,
    required String authorPubkey,
    required String privkeyHex,
  }) async {
    await transportService.leaveChannel(
      groupId: groupId,
      authorPubkey: authorPubkey,
      privkeyHex: privkeyHex,
    );
  }
}
