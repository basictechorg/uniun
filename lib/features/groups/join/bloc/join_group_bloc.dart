import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/usecases/save_group_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';

part 'join_group_event.dart';
part 'join_group_state.dart';

final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

@injectable
class JoinGroupBloc extends Bloc<JoinGroupEvent, JoinGroupState> {
  final SaveRelayUseCase _saveRelayUseCase;
  final SaveGroupUseCase _saveGroupUseCase;

  JoinGroupBloc(
    this._saveRelayUseCase,
    this._saveGroupUseCase,
  ) : super(const JoinGroupState()) {
    on<SubmitJoinGroupEvent>(_onSubmitJoin);
  }

  Future<void> _onSubmitJoin(
    SubmitJoinGroupEvent event,
    Emitter<JoinGroupState> emit,
  ) async {
    final groupId = event.groupId.trim();
    final groupName = event.groupName.trim();
    if (!_hex64.hasMatch(groupId)) {
      emit(state.copyWith(error: JoinGroupError.invalidId));
      return;
    }

    final selectedRelays = event.selectedRelays
        .map((relay) => relay.trim())
        .where((relay) => relay.isNotEmpty)
        .toSet()
        .toList();
    if (selectedRelays.isEmpty) {
      emit(state.copyWith(error: JoinGroupError.noRelay));
      return;
    }

    emit(state.copyWith(isSubmitting: true, error: null));

    for (final relay in selectedRelays) {
      final relaySaveResult = await _saveRelayUseCase.call(relay);
      if (relaySaveResult.isLeft()) {
        emit(
          state.copyWith(
            isSubmitting: false,
            error: JoinGroupError.relaySaveFailed,
          ),
        );
        return;
      }
    }

    final saveResult = await _saveGroupUseCase.call(
      GroupEntity(
        groupId: groupId,
        creatorPubKey: '',
        name: groupName,
        about: '',
        picture: '',
        relays: selectedRelays,
        createdAt: 0,
        updatedAt: 0,
      ),
    );

    saveResult.fold(
      (failure) => emit(
        state.copyWith(isSubmitting: false, error: JoinGroupError.saveFailed),
      ),
      (_) => emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          error: null,
        ),
      ),
    );
  }
}
