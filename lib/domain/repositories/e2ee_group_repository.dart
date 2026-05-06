import 'package:uniun/domain/entities/private_channel_entity.dart';
import 'package:uniun/domain/entities/private_channel_message_entity.dart';
import 'package:uniun/domain/entities/private_channel_join_request_entity.dart';

abstract class E2EEGroupRepository {
  Stream<List<PrivateChannelEntity>> watchChannels();
  Future<List<PrivateChannelEntity>> getChannels();
  
  Stream<List<PrivateChannelMessageEntity>> watchMessages(String groupId);
  Future<List<PrivateChannelMessageEntity>> getMessages(String groupId);
  
  Stream<List<PrivateChannelJoinRequestEntity>> watchJoinRequests(String groupId);
  Future<List<PrivateChannelJoinRequestEntity>> getJoinRequests(String groupId);
  
  Future<void> saveChannel(PrivateChannelEntity channel);
  Future<void> deleteChannel(String groupId);
}
