part of 'dm_chat_bloc.dart';

@immutable
sealed class DmChatEvent {}

final class DmChatLoadEvent extends DmChatEvent {
  final String otherPubkey;
  DmChatLoadEvent({required this.otherPubkey});
}

final class DmChatSendEvent extends DmChatEvent {
  final String content;
  final List<String> mentionRefs;
  final List<MediaBlobEntity> attachments;
  DmChatSendEvent({
    required this.content,
    this.mentionRefs = const [],
    this.attachments = const [],
  });
}

final class DmChatRefreshEvent extends DmChatEvent {}

/// A message scrolled past the viewport — delete its unread row.
final class DmChatMarkSeenEvent extends DmChatEvent {
  final String eventId;
  DmChatMarkSeenEvent(this.eventId);
}

/// The user reached the newest message — mark the whole conversation read.
final class DmChatMarkAllSeenEvent extends DmChatEvent {}
