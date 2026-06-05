part of 'user_profile_bloc.dart';

@freezed
abstract class UserProfileState with _$UserProfileState {
  const factory UserProfileState({
    String? pubkeyHex,
    String? hintName,
    ProfileEntity? profile,
    @Default(<NoteEntity>[]) List<NoteEntity> notes,
    @Default(false) bool loading,
    @Default(false) bool isFollowing,
    @Default(false) bool busy,
  }) = _UserProfileState;
}
