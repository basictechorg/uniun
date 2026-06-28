import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

abstract class JoinPrivateGroupEvent {}

class SubmitJoinPrivateGroupEvent extends JoinPrivateGroupEvent {
  final String groupId;
  final List<String> relays;

  SubmitJoinPrivateGroupEvent({
    required this.groupId,
    required this.relays,
  });
}

class JoinPrivateGroupState {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  JoinPrivateGroupState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  JoinPrivateGroupState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return JoinPrivateGroupState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}

@injectable
class JoinPrivateGroupBloc extends Bloc<JoinPrivateGroupEvent, JoinPrivateGroupState> {
  final JoinPrivateGroupUsecase _joinPrivateGroupUsecase;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  JoinPrivateGroupBloc(
    this._joinPrivateGroupUsecase,
    this._getActiveUserKeys,
  ) : super(JoinPrivateGroupState()) {
    on<SubmitJoinPrivateGroupEvent>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitJoinPrivateGroupEvent event,
    Emitter<JoinPrivateGroupState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);

      if (keys == null) {
        throw Exception('No active user found.');
      }

      await _joinPrivateGroupUsecase.execute(
        groupId: event.groupId,
        authorPubkey: keys.pubkeyHex,
        privkeyHex: keys.privkeyHex,
        relays: event.relays,
      );

      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
