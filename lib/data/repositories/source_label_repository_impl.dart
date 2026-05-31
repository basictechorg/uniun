import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/domain/repositories/source_label_repository.dart';

@Injectable(as: SourceLabelRepository)
class SourceLabelRepositoryImpl extends SourceLabelRepository {
  final Isar isar;
  SourceLabelRepositoryImpl({required this.isar});

  @override
  Future<Map<String, String>> resolveMany(
    Iterable<({String eventId, String? channelId, String? groupId})> items,
  ) async {
    final list = items.toList(growable: false);
    final channelIds = <String>{};
    final groupIds = <String>{};
    for (final i in list) {
      if (i.channelId != null) channelIds.add(i.channelId!);
      if (i.groupId != null) groupIds.add(i.groupId!);
    }

    final channelNames = <String, String>{};
    if (channelIds.isNotEmpty) {
      final rows = await isar.channelModels
          .filter()
          .anyOf(channelIds, (q, id) => q.channelIdEqualTo(id))
          .findAll();
      for (final c in rows) {
        channelNames[c.channelId] = c.name;
      }
    }

    final groupNames = <String, String>{};
    if (groupIds.isNotEmpty) {
      final rows = await isar.privateChannelModels
          .filter()
          .anyOf(groupIds, (q, id) => q.groupIdEqualTo(id))
          .findAll();
      for (final g in rows) {
        groupNames[g.groupId] = g.name;
      }
    }

    final out = <String, String>{};
    for (final item in list) {
      if (item.channelId != null) {
        final name = channelNames[item.channelId] ?? '';
        out[item.eventId] = name.isEmpty ? 'channel' : name;
      } else if (item.groupId != null) {
        final name = groupNames[item.groupId] ?? '';
        out[item.eventId] = name.isEmpty ? 'private' : name;
      }
    }
    return out;
  }
}
