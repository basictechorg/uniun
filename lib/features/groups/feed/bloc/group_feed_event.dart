import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

abstract class GroupFeedEvent {
  const GroupFeedEvent();
}

class LoadGroupFeedEvent extends GroupFeedEvent {
  const LoadGroupFeedEvent(this.groupId, {this.silent = false});
  final String groupId;
  /// When true the loading spinner is suppressed — used for background
  /// refreshes (e.g. returning from a thread) so scroll position is preserved.
  final bool silent;
}

/// Prepend a page of older (already-read) messages above the loaded range.
/// Fired as the user scrolls up toward the top.
class LoadOlderGroupMessagesEvent extends GroupFeedEvent {
  const LoadOlderGroupMessagesEvent(this.groupId);
  final String groupId;
}

/// Append a page of newer messages below the loaded range. Fired as the user
/// scrolls down toward the bottom. [isRefresh] bypasses the `hasMoreUnread`
/// guard so the bottom pull-to-refresh re-checks for newly-synced unread.
class LoadNewerGroupMessagesEvent extends GroupFeedEvent {
  const LoadNewerGroupMessagesEvent(this.groupId, {this.isRefresh = false});
  final String groupId;
  final bool isRefresh;
}

class SendGroupMessageEvent extends GroupFeedEvent {
  const SendGroupMessageEvent({
    required this.groupId,
    required this.content,
    this.replyToEventId,
    this.mentionRefs = const [],
    this.attachments = const [],
  });
  final String groupId;
  final String content;
  final String? replyToEventId;
  final List<String> mentionRefs;
  final List<MediaBlobEntity> attachments;
}

class SaveGroupFeedMessageEvent extends GroupFeedEvent {
  const SaveGroupFeedMessageEvent(this.message);
  final NoteEntity message;
}

class UnsaveGroupFeedMessageEvent extends GroupFeedEvent {
  const UnsaveGroupFeedMessageEvent(this.messageId);
  final String messageId;
}

/// A message scrolled past the viewport — delete its unread row.
class MarkGroupMessageSeenEvent extends GroupFeedEvent {
  const MarkGroupMessageSeenEvent(this.eventId);
  final String eventId;
}

/// The user reached the end of the list — mark every message in the group
/// read.
class MarkAllGroupSeenEvent extends GroupFeedEvent {
  const MarkAllGroupSeenEvent(this.groupId);
  final String groupId;
}
