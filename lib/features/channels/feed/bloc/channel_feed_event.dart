import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';

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
  final ChannelMessageEntity message;
}

class UnsaveChannelFeedMessageEvent extends ChannelFeedEvent {
  const UnsaveChannelFeedMessageEvent(this.messageId);
  final String messageId;
}
