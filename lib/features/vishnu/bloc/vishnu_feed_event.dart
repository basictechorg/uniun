part of 'vishnu_feed_bloc.dart';

sealed class VishnuFeedEvent {
  const VishnuFeedEvent();
}

/// Tab/app opened — load the first page. Idempotent.
final class FeedOpenedEvent extends VishnuFeedEvent {
  const FeedOpenedEvent();
}

/// Infinite-scroll request — load the next page from the current cursor.
final class LoadMoreFeedEvent extends VishnuFeedEvent {
  const LoadMoreFeedEvent();
}

/// Pill tap or pull-to-refresh — clear the list and re-fetch page 1.
final class RefreshFeedEvent extends VishnuFeedEvent {
  const RefreshFeedEvent();
}

/// A note scrolled past the viewport — flip `isSeen = true` in DB. The item
/// stays in [items] for the current session so the scroll position holds; it
/// will be excluded from the next page-1 query.
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

/// Internal — emitted by the unseen-above watcher.
final class _NewAboveCountChangedEvent extends VishnuFeedEvent {
  const _NewAboveCountChangedEvent(this.count);
  final int count;
}
