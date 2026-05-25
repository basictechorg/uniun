import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/utils/pubkey_normalizer.dart';
import 'package:uniun/domain/repositories/relay_repository.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';

part 'create_dm_event.dart';
part 'create_dm_state.dart';

@injectable
class CreateDmBloc extends Bloc<CreateDmEvent, CreateDmState> {
  final RelayRepository _relayRepository;
  final CreateDmConversationUseCase _createDmConversationUseCase;

  CreateDmBloc(this._relayRepository, this._createDmConversationUseCase)
    : super(const CreateDmState()) {
    on<LoadRelaysEvent>(_onLoadRelays);
    on<SubmitDmEvent>(_onSubmit);
  }

  Future<void> _onLoadRelays(
    LoadRelaysEvent event,
    Emitter<CreateDmState> emit,
  ) async {
    emit(state.copyWith(isLoadingRelays: true));
    try {
      final result = await _relayRepository.getAll();
      result.fold(
        (failure) => emit(
          state.copyWith(
            isLoadingRelays: false,
            errorMessage: failure.toMessage(),
          ),
        ),
        (relays) {
          final sorted = relays.map((r) => r.url).toList()..sort();
          emit(state.copyWith(isLoadingRelays: false, availableRelays: sorted));
        },
      );
    } catch (e) {
      emit(state.copyWith(isLoadingRelays: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onSubmit(
    SubmitDmEvent event,
    Emitter<CreateDmState> emit,
  ) async {
    if (event.otherPubkey.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'Recipient public key is required.'));
      // Clear flag so ui can try again
      emit(state.copyWith(errorMessage: null));
      return;
    }

    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    try {
      final resolvedPubkey = normalizeNostrPubkey(event.otherPubkey);
      if (resolvedPubkey.isEmpty) {
        emit(state.copyWith(errorMessage: 'Recipient public key must be a valid npub or 64-character hex.'));
        emit(state.copyWith(errorMessage: null));
        return;
      }

      final params = CreateDmParams(
        otherPubkey: resolvedPubkey,
        relays: event.selectedRelays,
      );

      final result = await _createDmConversationUseCase.call(params);

      result.fold(
        (failure) => emit(
          state.copyWith(
            isSubmitting: false,
            errorMessage: failure.toMessage(),
          ),
        ),
        (conv) => emit(state.copyWith(isSubmitting: false, isSuccess: true)),
      );
    } on FormatException {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Recipient public key must be a valid npub or 64-character hex.',
      ));
      emit(state.copyWith(errorMessage: null));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
