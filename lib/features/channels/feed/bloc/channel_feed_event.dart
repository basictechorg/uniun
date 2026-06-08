import 'package:uniun/domain/entities/note/note_entity.dart';

abstract class ChannelFeedEvent {
  const ChannelFeedEvent();
}

class LoadChannelFeedEvent extends ChannelFeedEvent {
  const LoadChannelFeedEvent(this.channelId, {this.silent = false});
  final String channelId;
  /// When true the loading spinner is suppressed — used for background
  /// refreshes (e.g. returning from a thread) so scroll position is preserved.
  final bool silent;
}

/// Prepend a page of older (already-read) messages above the loaded range.
/// Fired as the user scrolls up toward the top.
class LoadOlderChannelMessagesEvent extends ChannelFeedEvent {
  const LoadOlderChannelMessagesEvent(this.channelId);
  final String channelId;
}

/// Append a page of newer messages below the loaded range. Fired as the user
/// scrolls down toward the bottom. [isRefresh] bypasses the `hasMoreUnread`
/// guard so the bottom pull-to-refresh re-checks for newly-synced unread.
class LoadNewerChannelMessagesEvent extends ChannelFeedEvent {
  const LoadNewerChannelMessagesEvent(this.channelId, {this.isRefresh = false});
  final String channelId;
  final bool isRefresh;
}

class SendChannelMessageEvent extends ChannelFeedEvent {
  const SendChannelMessageEvent({
    required this.channelId,
    required this.content,
    this.replyToEventId,
    this.mentionRefs = const [],
  });
  final String channelId;
  final String content;
  final String? replyToEventId;
  final List<String> mentionRefs;
}

class SaveChannelFeedMessageEvent extends ChannelFeedEvent {
  const SaveChannelFeedMessageEvent(this.message);
  final NoteEntity message;
}

class UnsaveChannelFeedMessageEvent extends ChannelFeedEvent {
  const UnsaveChannelFeedMessageEvent(this.messageId);
  final String messageId;
}

/// A message scrolled past the viewport — delete its unread row.
class MarkChannelMessageSeenEvent extends ChannelFeedEvent {
  const MarkChannelMessageSeenEvent(this.eventId);
  final String eventId;
}

/// The user reached the end of the list — mark every message in the channel
/// read.
class MarkAllChannelSeenEvent extends ChannelFeedEvent {
  const MarkAllChannelSeenEvent(this.channelId);
  final String channelId;
}
