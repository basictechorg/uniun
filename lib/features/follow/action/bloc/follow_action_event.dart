part of 'follow_action_bloc.dart';

sealed class FollowActionEvent {
  const FollowActionEvent();
}

final class ResolveIdentityEvent extends FollowActionEvent {
  const ResolveIdentityEvent({required this.rawId, this.displayName});
  final String rawId;
  final String? displayName;
}

final class SubmitFollowEvent extends FollowActionEvent {
  const SubmitFollowEvent();
}
