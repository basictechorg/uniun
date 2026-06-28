import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/data/models/private_group_join_request_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_join_request_entity.dart';
import 'package:uniun/domain/repositories/e2ee_group_repository.dart';

@LazySingleton(as: E2EEGroupRepository)
class E2EEGroupRepositoryImpl implements E2EEGroupRepository {
  final Isar isar;
  final NoteAttachmentsEnricher _attachments;

  E2EEGroupRepositoryImpl(this.isar, this._attachments);

  @override
  Future<List<PrivateGroupEntity>> getGroups() async {
    final models = await isar.privateGroupModels.where().findAll();
    return models.map(_mapGroup).toList();
  }

  @override
  Stream<List<PrivateGroupEntity>> watchGroups() {
    return isar.privateGroupModels.where().watch(fireImmediately: true).map((models) {
      return models.map(_mapGroup).toList();
    });
  }

  @override
  Future<List<NoteEntity>> getMessages(String groupId) async {
    final models = await isar.noteModels
        .filter()
        .privateGroupIdEqualTo(groupId)
        .sortByCreated()
        .findAll();
    return _attachments
        .enrichAll([for (final m in models) m.toDomain()]);
  }

  @override
  Stream<List<NoteEntity>> watchMessages(String groupId) {
    return isar.noteModels
        .filter()
        .privateGroupIdEqualTo(groupId)
        .sortByCreated()
        .watch(fireImmediately: true)
        .asyncMap((models) =>
            _attachments.enrichAll([for (final m in models) m.toDomain()]));
  }

  @override
  Future<List<PrivateGroupJoinRequestEntity>> getJoinRequests(String groupId) async {
    final models = await isar.privateGroupJoinRequestModels
        .filter()
        .groupIdEqualTo(groupId)
        .handledEqualTo(false)
        .sortByTimestamp()
        .findAll();
    return models.map(_mapJoinRequest).toList();
  }

  @override
  Stream<List<PrivateGroupJoinRequestEntity>> watchJoinRequests(String groupId) {
    return isar.privateGroupJoinRequestModels
        .filter()
        .groupIdEqualTo(groupId)
        .handledEqualTo(false)
        .sortByTimestamp()
        .watch(fireImmediately: true)
        .map((models) {
      return models.map(_mapJoinRequest).toList();
    });
  }

  @override
  Future<void> saveGroup(PrivateGroupEntity group) async {
    final model = PrivateGroupModel()
      ..id = group.id > 0 ? group.id : Isar.autoIncrement
      ..groupId = group.groupId
      ..mlsGroupId = group.mlsGroupId
      ..relays = group.relays
      ..name = group.name
      ..description = group.description
      ..adminPubkey = group.adminPubkey;

    await isar.writeTxn(() async {
      await isar.privateGroupModels.put(model);
    });
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await isar.writeTxn(() async {
      await isar.privateGroupModels.where().groupIdEqualTo(groupId).deleteAll();
    });
  }

  PrivateGroupEntity _mapGroup(PrivateGroupModel model) {
    return PrivateGroupEntity(
      id: model.id,
      groupId: model.groupId,
      mlsGroupId: model.mlsGroupId,
      relays: model.relays,
      name: model.name,
      description: model.description,
      adminPubkey: model.adminPubkey,
    );
  }

  PrivateGroupJoinRequestEntity _mapJoinRequest(PrivateGroupJoinRequestModel model) {
    return PrivateGroupJoinRequestEntity(
      id: model.id,
      eventId: model.eventId,
      groupId: model.groupId,
      senderPubkey: model.senderPubkey,
      keyPackageB64: model.keyPackageB64,
      timestamp: model.timestamp,
    );
  }
}
