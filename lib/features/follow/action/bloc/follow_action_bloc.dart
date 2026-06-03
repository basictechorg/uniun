import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/utils/pubkey_normalizer.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';

part 'follow_action_event.dart';
part 'follow_action_state.dart';
part 'follow_action_bloc.freezed.dart';

@injectable
class FollowActionBloc extends Bloc<FollowActionEvent, FollowActionState> {
  final FollowUserUseCase _followUser;
  final GetProfileUseCase _getProfile;

  FollowActionBloc(this._followUser, this._getProfile)
      : super(const FollowActionState()) {
    on<ResolveIdentityEvent>(_onResolve);
    on<SubmitFollowEvent>(_onSubmit);
  }

  Future<void> _onResolve(
    ResolveIdentityEvent event,
    Emitter<FollowActionState> emit,
  ) async {
    try {
      final hex = normalizeNostrPubkey(event.rawId);
      emit(state.copyWith(pubkeyHex: hex, displayName: event.displayName));
      final profileResult = await _getProfile.call(hex);
      profileResult.fold(
        (_) {},
        (profile) => emit(state.copyWith(profile: profile)),
      );
    } on FormatException {
      emit(state.copyWith(invalid: true));
    }
  }

  Future<void> _onSubmit(
    SubmitFollowEvent event,
    Emitter<FollowActionState> emit,
  ) async {
    final hex = state.pubkeyHex;
    if (hex == null || state.busy) return;
    emit(state.copyWith(busy: true, errorMessage: null));
    final result = await _followUser.call(
      FollowUserInput(pubkeyHex: hex, petname: state.displayName),
    );
    result.fold(
      (f) => emit(state.copyWith(busy: false, errorMessage: f.toString())),
      (_) => emit(state.copyWith(busy: false, success: true)),
    );
  }
}
