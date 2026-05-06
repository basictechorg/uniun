import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

abstract class CreatePrivateChannelEvent {}

class SubmitCreatePrivateChannelEvent extends CreatePrivateChannelEvent {
  final String name;
  final String description;
  final List<String> relays;

  SubmitCreatePrivateChannelEvent({
    required this.name,
    required this.description,
    required this.relays,
  });
}

class CreatePrivateChannelState {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;
  final String? createdGroupId;

  CreatePrivateChannelState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
    this.createdGroupId,
  });

  CreatePrivateChannelState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    String? createdGroupId,
  }) {
    return CreatePrivateChannelState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
      createdGroupId: createdGroupId ?? this.createdGroupId,
    );
  }
}

@injectable
class CreatePrivateChannelBloc extends Bloc<CreatePrivateChannelEvent, CreatePrivateChannelState> {
  final CreatePrivateChannelUsecase _createPrivateChannelUsecase;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  CreatePrivateChannelBloc(
    this._createPrivateChannelUsecase,
    this._getActiveUserKeys,
  ) : super(CreatePrivateChannelState()) {
    on<SubmitCreatePrivateChannelEvent>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitCreatePrivateChannelEvent event,
    Emitter<CreatePrivateChannelState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);

      if (keys == null) {
        throw Exception('No active user found.');
      }

      // groupId is derived from the creation event ID inside the use case
      final groupId = await _createPrivateChannelUsecase.execute(
        privkeyHex: keys.privkeyHex,
        authorPubkey: keys.pubkeyHex,
        name: event.name,
        description: event.description,
        relays: event.relays,
      );

      emit(state.copyWith(isSubmitting: false, isSuccess: true, createdGroupId: groupId));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
