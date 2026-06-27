part of 'join_group_bloc.dart';

@immutable
sealed class JoinGroupEvent {
  const JoinGroupEvent();
}

final class SubmitJoinGroupEvent extends JoinGroupEvent {
  const SubmitJoinGroupEvent({
    required this.groupId,
    required this.selectedRelays,
    required this.groupName,
  });

  final String groupId;
  final List<String> selectedRelays;
  final String groupName;
}
