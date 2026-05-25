import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

abstract class JoinPrivateChannelEvent {}

class SubmitJoinPrivateChannelEvent extends JoinPrivateChannelEvent {
  final String groupId;
  final List<String> relays;

  SubmitJoinPrivateChannelEvent({
    required this.groupId,
    required this.relays,
  });
}

class JoinPrivateChannelState {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  JoinPrivateChannelState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  JoinPrivateChannelState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return JoinPrivateChannelState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}

@injectable
class JoinPrivateChannelBloc extends Bloc<JoinPrivateChannelEvent, JoinPrivateChannelState> {
  final JoinPrivateChannelUsecase _joinPrivateChannelUsecase;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  JoinPrivateChannelBloc(
    this._joinPrivateChannelUsecase,
    this._getActiveUserKeys,
  ) : super(JoinPrivateChannelState()) {
    on<SubmitJoinPrivateChannelEvent>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitJoinPrivateChannelEvent event,
    Emitter<JoinPrivateChannelState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);

      if (keys == null) {
        throw Exception('No active user found.');
      }

      await _joinPrivateChannelUsecase.execute(
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
