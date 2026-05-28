import 'package:isar_community/isar.dart';

part 'pending_extraction_model.g.dart';

/// A note that was embedded + vector-stored but whose graph/memory extraction
/// did not complete (preempted by chat, model unavailable, or any failure).
///
/// One row is written at the start of [ExtractKnowledgeUseCase] and deleted
/// only on a clean finish. Anything left behind is replayed when the Shiv tab
/// closes (and may also be drained on app launch in the future).
@Collection(ignore: {'copyWith'})
@Name('PendingExtraction')
class PendingExtractionModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String noteId;

  late String content;
  late List<double> vec;
  late DateTime createdAt;
}
