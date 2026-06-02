import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';

@Injectable(as: NoteRelationRepository)
class NoteRelationRepositoryImpl extends NoteRelationRepository {
  final Isar isar;

  NoteRelationRepositoryImpl({required this.isar});

  @override
  Future<int> replyCount(String parentId) => isar.noteRelationModels
      .filter()
      .parentIdEqualTo(parentId)
      .count();

  @override
  Future<int> referenceCount(String childId) => isar.noteRelationModels
      .filter()
      .childIdEqualTo(childId)
      .count();

  @override
  Future<List<String>> childIdsOf(String parentId) => isar.noteRelationModels
      .filter()
      .parentIdEqualTo(parentId)
      .childIdProperty()
      .findAll();

  @override
  Future<List<String>> parentIdsOf(String childId) => isar.noteRelationModels
      .filter()
      .childIdEqualTo(childId)
      .parentIdProperty()
      .findAll();

  @override
  Future<void> addEdgesInTxn({
    required Set<String> parents,
    required String childId,
  }) async {
    final now = DateTime.now();
    for (final parentId in parents) {
      await isar.noteRelationModels.put(
        NoteRelationModel()
          ..parentId = parentId
          ..childId = childId
          ..createdAt = now,
      );
    }
  }
}
