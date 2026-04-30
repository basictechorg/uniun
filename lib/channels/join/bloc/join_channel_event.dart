part of 'join_channel_bloc.dart';

@immutable
sealed class JoinChannelEvent {
  const JoinChannelEvent();
}

final class LoadJoinRelaysEvent extends JoinChannelEvent {
  const LoadJoinRelaysEvent();
}

final class AddJoinRelayEvent extends JoinChannelEvent {
  const AddJoinRelayEvent({required this.url});

  final String url;
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

final class SubmitJoinChannelQrEvent extends JoinChannelEvent {
  const SubmitJoinChannelQrEvent({required this.rawPayload});

  final String rawPayload;
}
