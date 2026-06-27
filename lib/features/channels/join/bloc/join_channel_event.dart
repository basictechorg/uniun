part of 'join_channel_bloc.dart';

@immutable
sealed class JoinChannelEvent {
  const JoinChannelEvent();
}

final class SubmitJoinChannelEvent extends JoinChannelEvent {
  const SubmitJoinChannelEvent({
    required this.channelId,
    required this.selectedRelays,
    required this.channelName,
  });

  final String channelId;
  final List<String> selectedRelays;
  final String channelName;
}
