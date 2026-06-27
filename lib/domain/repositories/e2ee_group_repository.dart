import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_join_request_entity.dart';

abstract class E2EEGroupRepository {
  Stream<List<PrivateGroupEntity>> watchGroups();
  Future<List<PrivateGroupEntity>> getGroups();

  Stream<List<NoteEntity>> watchMessages(String groupId);
  Future<List<NoteEntity>> getMessages(String groupId);
  
  Stream<List<PrivateGroupJoinRequestEntity>> watchJoinRequests(String groupId);
  Future<List<PrivateGroupJoinRequestEntity>> getJoinRequests(String groupId);
  
  Future<void> saveGroup(PrivateGroupEntity group);
  Future<void> deleteGroup(String groupId);
}
