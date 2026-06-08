import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/data/models/private_channel_join_request_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_join_request_entity.dart';
import 'package:uniun/domain/repositories/e2ee_group_repository.dart';

@LazySingleton(as: E2EEGroupRepository)
class E2EEGroupRepositoryImpl implements E2EEGroupRepository {
  final Isar isar;

  E2EEGroupRepositoryImpl(this.isar);

  @override
  Future<List<PrivateChannelEntity>> getChannels() async {
    final models = await isar.privateChannelModels.where().findAll();
    return models.map(_mapChannel).toList();
  }

  @override
  Stream<List<PrivateChannelEntity>> watchChannels() {
    return isar.privateChannelModels.where().watch(fireImmediately: true).map((models) {
      return models.map(_mapChannel).toList();
    });
  }

  @override
  Future<List<NoteEntity>> getMessages(String groupId) async {
    final models = await isar.noteModels
        .filter()
        .groupIdEqualTo(groupId)
        .sortByCreated()
        .findAll();
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Stream<List<NoteEntity>> watchMessages(String groupId) {
    return isar.noteModels
        .filter()
        .groupIdEqualTo(groupId)
        .sortByCreated()
        .watch(fireImmediately: true)
        .map((models) {
      return models.map((m) => m.toDomain()).toList();
    });
  }

  @override
  Future<List<PrivateChannelJoinRequestEntity>> getJoinRequests(String groupId) async {
    final models = await isar.privateChannelJoinRequestModels
        .where()
        .groupIdEqualTo(groupId)
        .sortByTimestamp()
        .findAll();
    return models.map(_mapJoinRequest).toList();
  }

  @override
  Stream<List<PrivateChannelJoinRequestEntity>> watchJoinRequests(String groupId) {
    return isar.privateChannelJoinRequestModels
        .filter()
        .groupIdEqualTo(groupId)
        .sortByTimestamp()
        .watch(fireImmediately: true)
        .map((models) {
      return models.map(_mapJoinRequest).toList();
    });
  }

  @override
  Future<void> saveChannel(PrivateChannelEntity channel) async {
    final model = PrivateChannelModel()
      ..id = channel.id > 0 ? channel.id : Isar.autoIncrement
      ..groupId = channel.groupId
      ..mlsGroupId = channel.mlsGroupId
      ..relays = channel.relays
      ..name = channel.name
      ..description = channel.description
      ..adminPubkey = channel.adminPubkey;

    await isar.writeTxn(() async {
      await isar.privateChannelModels.put(model);
    });
  }

  @override
  Future<void> deleteChannel(String groupId) async {
    await isar.writeTxn(() async {
      await isar.privateChannelModels.where().groupIdEqualTo(groupId).deleteAll();
    });
  }

  PrivateChannelEntity _mapChannel(PrivateChannelModel model) {
    return PrivateChannelEntity(
      id: model.id,
      groupId: model.groupId,
      mlsGroupId: model.mlsGroupId,
      relays: model.relays,
      name: model.name,
      description: model.description,
      adminPubkey: model.adminPubkey,
    );
  }

  PrivateChannelJoinRequestEntity _mapJoinRequest(PrivateChannelJoinRequestModel model) {
    return PrivateChannelJoinRequestEntity(
      id: model.id,
      eventId: model.eventId,
      groupId: model.groupId,
      senderPubkey: model.senderPubkey,
      keyPackageB64: model.keyPackageB64,
      timestamp: model.timestamp,
    );
  }
}
