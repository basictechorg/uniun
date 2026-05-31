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
  DmChatSendEvent({required this.content, this.mentionRefs = const []});
}

final class DmChatRefreshEvent extends DmChatEvent {}
