import 'package:uniun/domain/repositories/note_relation_repository.dart';

/// Deterministic [NoteRelationRepository] test double.
///
/// Seed [children] / [parents] before the test runs — the returned lists are
/// what the repository under test will see. Not thread-safe; single-turn use.
class FakeNoteRelations implements NoteRelationRepository {
  final Map<String, List<String>> children = {};
  final Map<String, List<String>> parents = {};

  @override
  Future<List<String>> childIdsOf(String parentId) async =>
      children[parentId] ?? const [];

  @override
  Future<List<String>> parentIdsOf(String childId) async =>
      parents[childId] ?? const [];

  @override
  Future<int> replyCount(String parentId) async =>
      (children[parentId] ?? const []).length;

  @override
  Future<int> referenceCount(String childId) async =>
      (parents[childId] ?? const []).length;

  @override
  Future<void> addEdgesInTxn({
    required Set<String> parents,
    required String childId,
  }) async {
    // Not exercised by tests that use this fake — override if you need it.
  }
}
