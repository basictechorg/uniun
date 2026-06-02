import 'package:isar_community/isar.dart';

part 'feed_read_state_model.g.dart';

/// Singleton row (id = 0) that holds the Vishnu feed's reading-progress
/// anchor. Used by the three-bucket ordering:
///   - New buffer = !isSeen && created >  feedLoadedAt   (banner only)
///   - Queue      = !isSeen && created <= feedLoadedAt   (top of feed)
///   - Seen       = isSeen                               (after queue)
///
/// Persisted across app restarts so the queue survives a relaunch. Advanced
/// on banner tap / pull-to-refresh.
@Collection(ignore: {'copyWith'})
@Name('FeedReadState')
class FeedReadStateModel {
  Id id = 0;

  late DateTime feedLoadedAt;
}
