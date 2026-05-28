import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/pending_extraction_model.dart';
import 'package:uniun/domain/repositories/pending_extraction_repository.dart';

@Injectable(as: PendingExtractionRepository)
class PendingExtractionRepositoryImpl extends PendingExtractionRepository {
  final Isar isar;
  PendingExtractionRepositoryImpl({required this.isar});

  @override
  Future<void> mark(String noteId, String content, List<double> vec) async {
    await isar.writeTxn(() async {
      final row = PendingExtractionModel()
        ..noteId = noteId
        ..content = content
        ..vec = vec
        ..createdAt = DateTime.now();
      await isar.pendingExtractionModels.put(row);
    });
  }

  @override
  Future<void> clear(String noteId) async {
    await isar.writeTxn(() async {
      await isar.pendingExtractionModels
          .filter()
          .noteIdEqualTo(noteId)
          .deleteAll();
    });
  }

  @override
  Future<List<PendingExtractionItem>> all() async {
    final rows = await isar.pendingExtractionModels
        .where()
        .sortByCreatedAt()
        .findAll();
    return rows
        .map((r) => PendingExtractionItem(
              noteId: r.noteId,
              content: r.content,
              vec: r.vec,
            ))
        .toList();
  }
}
