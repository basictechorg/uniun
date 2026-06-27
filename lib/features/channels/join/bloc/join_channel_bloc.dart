import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/usecases/save_channel_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';

part 'join_channel_event.dart';
part 'join_channel_state.dart';

final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

@injectable
class JoinChannelBloc extends Bloc<JoinChannelEvent, JoinChannelState> {
  final SaveRelayUseCase _saveRelayUseCase;
  final SaveChannelUseCase _saveChannelUseCase;

  JoinChannelBloc(
    this._saveRelayUseCase,
    this._saveChannelUseCase,
  ) : super(const JoinChannelState()) {
    on<SubmitJoinChannelEvent>(_onSubmitJoin);
  }

  Future<void> _onSubmitJoin(
    SubmitJoinChannelEvent event,
    Emitter<JoinChannelState> emit,
  ) async {
    final channelId = event.channelId.trim();
    final channelName = event.channelName.trim();
    if (!_hex64.hasMatch(channelId)) {
      emit(state.copyWith(error: JoinChannelError.invalidId));
      return;
    }

    final selectedRelays = event.selectedRelays
        .map((relay) => relay.trim())
        .where((relay) => relay.isNotEmpty)
        .toSet()
        .toList();
    if (selectedRelays.isEmpty) {
      emit(state.copyWith(error: JoinChannelError.noRelay));
      return;
    }

    emit(state.copyWith(isSubmitting: true, error: null));

    for (final relay in selectedRelays) {
      final relaySaveResult = await _saveRelayUseCase.call(relay);
      if (relaySaveResult.isLeft()) {
        emit(
          state.copyWith(
            isSubmitting: false,
            error: JoinChannelError.relaySaveFailed,
          ),
        );
        return;
      }
    }

    final saveResult = await _saveChannelUseCase.call(
      ChannelEntity(
        channelId: channelId,
        creatorPubKey: '',
        name: channelName,
        about: '',
        picture: '',
        relays: selectedRelays,
        createdAt: 0,
        updatedAt: 0,
      ),
    );

    saveResult.fold(
      (failure) => emit(
        state.copyWith(isSubmitting: false, error: JoinChannelError.saveFailed),
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
