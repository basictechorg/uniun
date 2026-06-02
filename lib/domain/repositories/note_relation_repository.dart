/// Reference-edge repository.
///
/// All reply / reference counts and edge writes go through this. Other repos
/// (notes, channel messages, saved notes) call into this one instead of
/// touching the `NoteRelationModel` collection directly.
abstract class NoteRelationRepository {
  /// Incoming reply count — edges pointing TO [parentId].
  Future<int> replyCount(String parentId);

  /// Outgoing reference count — edges originating FROM [childId].
  Future<int> referenceCount(String childId);

  /// All child event ids that reference [parentId].
  Future<List<String>> childIdsOf(String parentId);

  /// All parent event ids that [childId] references.
  Future<List<String>> parentIdsOf(String childId);

  /// Persists one reference edge per parent for [childId]. Idempotent — the
  /// unique (parentId, childId) index makes re-delivery a no-op.
  ///
  /// MUST be called from inside an existing Isar `writeTxn` opened by the
  /// caller, so the edges commit atomically with the note/message write.
  Future<void> addEdgesInTxn({
    required Set<String> parents,
    required String childId,
  });
}
