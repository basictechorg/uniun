import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/domain/repositories/source_label_repository.dart';

@Injectable(as: SourceLabelRepository)
class SourceLabelRepositoryImpl extends SourceLabelRepository {
  final Isar isar;
  SourceLabelRepositoryImpl({required this.isar});

  @override
  Future<Map<String, String>> resolveMany(
    Iterable<({String eventId, String? groupId, String? privateGroupId})> items,
  ) async {
    final list = items.toList(growable: false);
    final publicIds = <String>{};
    final privateIds = <String>{};
    for (final i in list) {
      if (i.groupId != null) publicIds.add(i.groupId!);
      if (i.privateGroupId != null) privateIds.add(i.privateGroupId!);
    }

    final publicNames = <String, String>{};
    if (publicIds.isNotEmpty) {
      final rows = await isar.groupModels
          .filter()
          .anyOf(publicIds, (q, id) => q.groupIdEqualTo(id))
          .findAll();
      for (final c in rows) {
        publicNames[c.groupId] = c.name;
      }
    }

    final privateNames = <String, String>{};
    if (privateIds.isNotEmpty) {
      final rows = await isar.privateGroupModels
          .filter()
          .anyOf(privateIds, (q, id) => q.groupIdEqualTo(id))
          .findAll();
      for (final g in rows) {
        privateNames[g.groupId] = g.name;
      }
    }

    final out = <String, String>{};
    for (final item in list) {
      if (item.groupId != null) {
        final name = publicNames[item.groupId] ?? '';
        out[item.eventId] = name.isEmpty ? 'group' : name;
      } else if (item.privateGroupId != null) {
        final name = privateNames[item.privateGroupId] ?? '';
        out[item.eventId] = name.isEmpty ? 'private' : name;
      }
    }
    return out;
  }
}
