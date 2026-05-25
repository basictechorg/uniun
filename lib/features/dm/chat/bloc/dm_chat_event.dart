part of 'dm_chat_bloc.dart';

@immutable
sealed class DmChatEvent {}

final class DmChatLoadEvent extends DmChatEvent {
  final String otherPubkey;
  DmChatLoadEvent({required this.otherPubkey});
}

final class DmChatSendEvent extends DmChatEvent {
  final String content;
  DmChatSendEvent({required this.content});
}

final class DmChatRefreshEvent extends DmChatEvent {}
