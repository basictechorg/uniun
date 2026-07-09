import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/surrounding_note_model.dart';
import 'package:uniun/data/models/surrounding_tombstone_model.dart';

/// Evicts surrounding notes older than a cutoff (called daily). Cache eviction,
/// not deletion — surrounding notes are inherently ephemeral.
class SurroundingCleanup {
  SurroundingCleanup(this._isar);

  final Isar _isar;

  Future<int> evictFirstSeenBefore(DateTime cutoff) async {
    var count = 0;
    await _isar.writeTxn(() async {
      count = await _isar.surroundingNoteModels
          .filter()
          .firstSeenAtLessThan(cutoff)
          .deleteAll();
    });
    return count;
  }

  /// Expires user-deletion tombstones older than [cutoff]. Once gone, a note may
  /// reappear if still broadcast — fine for an ephemeral surface. Keeps the
  /// tombstone table from growing without bound.
  Future<int> evictTombstonesBefore(DateTime cutoff) async {
    var count = 0;
    await _isar.writeTxn(() async {
      count = await _isar.surroundingTombstoneModels
          .filter()
          .deletedAtLessThan(cutoff)
          .deleteAll();
    });
    return count;
  }
}
