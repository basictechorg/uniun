import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/channels/join/utils/join_channel_qr_parser.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/save_channel_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';

part 'join_channel_event.dart';
part 'join_channel_state.dart';

@injectable
class JoinChannelBloc extends Bloc<JoinChannelEvent, JoinChannelState> {
  final GetRelaysUseCase _getRelaysUseCase;
  final SaveRelayUseCase _saveRelayUseCase;
  final SaveChannelUseCase _saveChannelUseCase;

  JoinChannelBloc(
    this._getRelaysUseCase,
    this._saveRelayUseCase,
    this._saveChannelUseCase,
  ) : super(const JoinChannelState()) {
    on<LoadJoinRelaysEvent>(_onLoadRelays);
    on<AddJoinRelayEvent>(_onAddRelay);
    on<SubmitJoinChannelEvent>(_onSubmitJoin);
    on<SubmitJoinChannelQrEvent>(_onSubmitJoinQr);
  }

  Future<void> _onLoadRelays(
    LoadJoinRelaysEvent event,
    Emitter<JoinChannelState> emit,
  ) async {
    emit(state.copyWith(isLoadingRelays: true, errorMessage: null));

    final result = await _getRelaysUseCase.call();
    result.fold(
      (failure) => emit(
        state.copyWith(isLoadingRelays: false, errorMessage: failure.message),
      ),
      (relays) => emit(
        state.copyWith(
          isLoadingRelays: false,
          availableRelays: relays.map((relay) => relay.url).toList(),
          errorMessage: null,
        ),
      ),
    );
  }

  Future<void> _onAddRelay(
    AddJoinRelayEvent event,
    Emitter<JoinChannelState> emit,
  ) async {
    final relayUrl = event.url.trim();

    final saveResult = await _saveRelayUseCase.call(relayUrl);
    await saveResult.fold(
      (failure) async {
        emit(state.copyWith(errorMessage: failure.message));
      },
      (_) async {
        add(const LoadJoinRelaysEvent());
      },
    );
  }

  Future<void> _onSubmitJoin(
    SubmitJoinChannelEvent event,
    Emitter<JoinChannelState> emit,
  ) async {
    final channelId = event.channelId.trim();
    final channelName = event.channelName.trim();
    if (!JoinChannelQrParser.isValidChannelId(channelId)) {
      emit(
        state.copyWith(errorMessage: 'Enter a valid 64-character channel id.'),
      );
      return;
    }

    final selectedRelays = event.selectedRelays
        .map((relay) => relay.trim())
        .where((relay) => relay.isNotEmpty)
        .toSet()
        .toList();
    if (selectedRelays.isEmpty) {
      emit(state.copyWith(errorMessage: 'Please select at least one relay.'));
      return;
    }

    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    for (final relay in selectedRelays) {
      final relaySaveResult = await _saveRelayUseCase.call(relay);
      if (relaySaveResult.isLeft()) {
        emit(
          state.copyWith(
            isSubmitting: false,
            errorMessage: 'Failed to save relay locally.',
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
        state.copyWith(isSubmitting: false, errorMessage: failure.message),
      ),
      (_) => emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          errorMessage: null,
        ),
      ),
    );
  }

  Future<void> _onSubmitJoinQr(
    SubmitJoinChannelQrEvent event,
    Emitter<JoinChannelState> emit,
  ) async {
    try {
      final payload = JoinChannelQrParser.parse(event.rawPayload);
      add(
        SubmitJoinChannelEvent(
          channelId: payload.channelId,
          selectedRelays: payload.relays,
          channelName: payload.channelName,
        ),
      );
    } on FormatException catch (error) {
      emit(state.copyWith(errorMessage: error.message));
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Failed to parse QR code.'));
    }
  }
}
