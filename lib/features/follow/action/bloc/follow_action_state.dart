part of 'follow_action_bloc.dart';

@freezed
abstract class FollowActionState with _$FollowActionState {
  const factory FollowActionState({
    String? pubkeyHex,
    String? displayName,
    ProfileEntity? profile,
    @Default(false) bool busy,
    @Default(false) bool invalid,
    @Default(false) bool success,
    String? errorMessage,
  }) = _FollowActionState;
}
