import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

abstract class CreatePrivateGroupEvent {}

class SubmitCreatePrivateGroupEvent extends CreatePrivateGroupEvent {
  final String name;
  final String description;
  final List<String> relays;

  SubmitCreatePrivateGroupEvent({
    required this.name,
    required this.description,
    required this.relays,
  });
}

class CreatePrivateGroupState {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;
  final String? createdGroupId;

  CreatePrivateGroupState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
    this.createdGroupId,
  });

  CreatePrivateGroupState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    String? createdGroupId,
  }) {
    return CreatePrivateGroupState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
      createdGroupId: createdGroupId ?? this.createdGroupId,
    );
  }
}

@injectable
class CreatePrivateGroupBloc extends Bloc<CreatePrivateGroupEvent, CreatePrivateGroupState> {
  final CreatePrivateGroupUsecase _createPrivateGroupUsecase;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  CreatePrivateGroupBloc(
    this._createPrivateGroupUsecase,
    this._getActiveUserKeys,
  ) : super(CreatePrivateGroupState()) {
    on<SubmitCreatePrivateGroupEvent>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitCreatePrivateGroupEvent event,
    Emitter<CreatePrivateGroupState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);

      if (keys == null) {
        throw Exception('No active user found.');
      }

      // groupId is derived from the creation event ID inside the use case
      final groupId = await _createPrivateGroupUsecase.execute(
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
