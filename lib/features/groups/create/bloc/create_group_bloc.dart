import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/domain/usecases/create_group_usecase.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

part 'create_group_event.dart';
part 'create_group_state.dart';

@injectable
class CreateGroupBloc extends Bloc<CreateGroupEvent, CreateGroupState> {
  final GetRelaysUseCase _getRelaysUseCase;
  final GetActiveUserUseCase _getActiveUserUseCase;
  final CreateGroupUseCase _createGroupUseCase;

  CreateGroupBloc(
    this._getRelaysUseCase,
    this._getActiveUserUseCase,
    this._createGroupUseCase,
  ) : super(const CreateGroupState()) {
    on<LoadRelaysEvent>(_onLoadRelays);
    on<SubmitGroupEvent>(_onSubmitGroup);
  }

  Future<void> _onLoadRelays(
    LoadRelaysEvent event,
    Emitter<CreateGroupState> emit,
  ) async {
    emit(state.copyWith(isLoadingRelays: true, errorMessage: null));

    final result = await _getRelaysUseCase.call();
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isLoadingRelays: false,
            errorMessage: 'Failed to load relays.',
          ),
        );
      },
      (relays) {
        emit(
          state.copyWith(
            isLoadingRelays: false,
            availableRelays: relays.map((r) => r.url).toList(),
          ),
        );
      },
    );
  }

  Future<void> _onSubmitGroup(
    SubmitGroupEvent event,
    Emitter<CreateGroupState> emit,
  ) async {
    // Validation
    if (event.name.trim().length < 3) {
      emit(
        state.copyWith(
          errorMessage: 'Group name must be at least 3 characters.',
        ),
      );
      return;
    }

    if (event.name.trim().length > 30) {
      emit(
        state.copyWith(
          errorMessage: 'Group name cannot exceed 30 characters.',
        ),
      );
      return;
    }

    if (event.selectedRelays.isEmpty) {
      emit(state.copyWith(errorMessage: 'Please select at least one relay.'));
      return;
    }

    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    // Get active user for signing
    final userResult = await _getActiveUserUseCase.call();
    final user = userResult.fold((_) => null, (u) => u);

    if (user == null) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Active user not found or missing private key.',
        ),
      );
      return;
    }

    String hexPriv = user.nsec;
    if (hexPriv.startsWith('nsec1')) {
      try {
        hexPriv = Nip19.decodePrivkey(hexPriv);
      } catch (e) {
        emit(
          state.copyWith(
            isSubmitting: false,
            errorMessage: 'Failed to decode private key.',
          ),
        );
        return;
      }
    }

    final input = CreateGroupInput(
      name: event.name.trim(),
      about: event.about.trim(),
      picture: event.picture.trim(),
      relays: event.selectedRelays,
      privateKey: hexPriv,
    );

    final createResult = await _createGroupUseCase.call(input);

    createResult.fold(
      (failure) {
        emit(
          state.copyWith(isSubmitting: false, errorMessage: failure.message),
        );
      },
      (group) {
        // Success
        emit(state.copyWith(isSubmitting: false, isSuccess: true));
      },
    );
  }
}
