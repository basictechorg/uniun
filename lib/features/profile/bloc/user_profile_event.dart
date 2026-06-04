part of 'user_profile_bloc.dart';

sealed class UserProfileEvent {
  const UserProfileEvent();
}

final class LoadUserProfileEvent extends UserProfileEvent {
  const LoadUserProfileEvent(this.pubkeyHex, {this.hintName});
  final String pubkeyHex;
  final String? hintName;
}

final class ToggleFollowEvent extends UserProfileEvent {
  const ToggleFollowEvent();
}

final class ProfileChangedEvent extends UserProfileEvent {
  const ProfileChangedEvent(this.profile);
  final ProfileEntity? profile;
}
