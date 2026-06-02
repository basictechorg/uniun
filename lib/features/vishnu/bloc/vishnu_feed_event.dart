part of 'vishnu_feed_bloc.dart';

sealed class VishnuFeedEvent {
  const VishnuFeedEvent();
}

/// Tab/app opened — load the persisted anchor and first page. Idempotent.
final class FeedOpenedEvent extends VishnuFeedEvent {
  const FeedOpenedEvent();
}

/// Infinite-scroll request — load the next page from the current cursor.
final class LoadMoreFeedEvent extends VishnuFeedEvent {
  const LoadMoreFeedEvent();
}

/// Banner tap — advance `feedLoadedAt = now`, re-bucket, reload from top.
final class LoadNewNotesEvent extends VishnuFeedEvent {
  const LoadNewNotesEvent();
}

/// Pull-to-refresh — same as banner tap.
final class RefreshFeedEvent extends VishnuFeedEvent {
  const RefreshFeedEvent();
}

/// A note scrolled past the viewport — flip `isSeen = true` in DB.
final class MarkFeedItemSeenEvent extends VishnuFeedEvent {
  const MarkFeedItemSeenEvent(this.eventId);
  final String eventId;
}

final class SaveFeedNoteEvent extends VishnuFeedEvent {
  const SaveFeedNoteEvent(this.note);
  final NoteEntity note;
}

final class UnsaveFeedNoteEvent extends VishnuFeedEvent {
  const UnsaveFeedNoteEvent(this.noteId);
  final String noteId;
}

/// Internal — emitted by the banner-count watcher.
final class _NewBufferCountChangedEvent extends VishnuFeedEvent {
  const _NewBufferCountChangedEvent(this.count);
  final int count;
}
