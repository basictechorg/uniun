/// Persisted retry queue for graph/memory extractions that were preempted or
/// failed. Drained when the Shiv tab closes.
abstract class PendingExtractionRepository {
  /// Marks `noteId` as pending. Idempotent — replaces any existing row for the
  /// same noteId. Written at the start of an extraction attempt; removed only
  /// once the extraction has fully persisted graph + memory.
  Future<void> mark(String noteId, String content, List<double> vec);

  /// Removes the row for `noteId` (extraction succeeded).
  Future<void> clear(String noteId);

  /// Returns all pending rows in insertion order.
  Future<List<PendingExtractionItem>> all();
}

class PendingExtractionItem {
  const PendingExtractionItem({
    required this.noteId,
    required this.content,
    required this.vec,
  });
  final String noteId;
  final String content;
  final List<double> vec;
}
