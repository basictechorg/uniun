import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';
part 'user_profile_bloc.freezed.dart';

@injectable
class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final GetOwnNotesUseCase _getOwnNotes;
  final IsFollowingUseCase _isFollowing;
  final FollowUserUseCase _followUser;
  final UnfollowUserUseCase _unfollowUser;
  final WatchProfileUseCase _watchProfile;
  final RequestProfileFetchUseCase _requestProfileFetch;
  final GetActiveUserUseCase _getActiveUser;

  StreamSubscription<ProfileEntity?>? _profileSub;

  UserProfileBloc(
    this._getOwnNotes,
    this._isFollowing,
    this._followUser,
    this._unfollowUser,
    this._watchProfile,
    this._requestProfileFetch,
    this._getActiveUser,
  ) : super(const UserProfileState()) {
    on<LoadUserProfileEvent>(_onLoad);
    on<ToggleFollowEvent>(_onToggleFollow);
    on<ProfileChangedEvent>(_onProfileChanged);
  }

  @override
  Future<void> close() async {
    await _profileSub?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    LoadUserProfileEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(
      loading: true,
      pubkeyHex: event.pubkeyHex,
      hintName: event.hintName,
    ));

    final activeUserResult = await _getActiveUser.call();
    activeUserResult.fold(
      (_) {},
      (user) => emit(state.copyWith(isSelf: user.pubkeyHex == event.pubkeyHex)),
    );

    await _profileSub?.cancel();
    _profileSub = _watchProfile.call(event.pubkeyHex).listen(
          (p) => add(ProfileChangedEvent(p)),
        );

    final notesResult = await _getOwnNotes.call(event.pubkeyHex);
    notesResult.fold(
      (_) => emit(state.copyWith(notes: const [])),
      (list) {
        final topLevel = list.where((n) => n.rootEventId == null).toList();
        emit(state.copyWith(notes: topLevel));
      },
    );

    final followResult = await _isFollowing.call(event.pubkeyHex);
    followResult.fold(
      (_) {},
      (v) => emit(state.copyWith(isFollowing: v)),
    );

    if (state.profile == null) {
      await _requestProfileFetch.call(event.pubkeyHex);
      // Give the relay a window to return Kind 0 before showing fallback UI.
      await Future.any([
        stream
            .firstWhere((s) => s.profile != null)
            .then((_) => null),
        Future<void>.delayed(const Duration(seconds: 4)),
      ]);
    }

    emit(state.copyWith(loading: false));
  }

  void _onProfileChanged(
    ProfileChangedEvent event,
    Emitter<UserProfileState> emit,
  ) {
    emit(state.copyWith(profile: event.profile));
  }

  Future<void> _onToggleFollow(
    ToggleFollowEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    final hex = state.pubkeyHex;
    if (hex == null || state.busy) return;
    emit(state.copyWith(busy: true));
    if (state.isFollowing) {
      final result = await _unfollowUser.call(hex);
      result.fold(
        (_) => emit(state.copyWith(busy: false)),
        (_) => emit(state.copyWith(busy: false, isFollowing: false)),
      );
    } else {
      final result = await _followUser.call(
        FollowUserInput(
          pubkeyHex: hex,
          petname: state.profile?.name,
        ),
      );
      result.fold(
        (_) => emit(state.copyWith(busy: false)),
        (_) => emit(state.copyWith(busy: false, isFollowing: true)),
      );
    }
  }
}
