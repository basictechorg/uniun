import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/dm_message_model.dart';
import 'package:uniun/domain/entities/dm/dm_message_entity.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';

part 'dm_chat_event.dart';
part 'dm_chat_state.dart';

@injectable
class DmChatBloc extends Bloc<DmChatEvent, DmChatState> {
  final FetchDmUseCase _fetchDmUseCase;
  final SendDmUseCase _sendDmUseCase;
  final GetDmUseCase _getDmUseCase;
  final Isar _isar;
  StreamSubscription<void>? _messageWatcher;

  DmChatBloc(
    this._fetchDmUseCase,
    this._sendDmUseCase,
    this._getDmUseCase,
    this._isar,
  ) : super(const DmChatState()) {
    on<DmChatLoadEvent>(_onLoad);
    on<DmChatSendEvent>(_onSend);
    on<DmChatRefreshEvent>(_onRefresh);
  }

  Future<void> _onLoad(DmChatLoadEvent event, Emitter<DmChatState> emit) async {
    emit(state.copyWith(isLoading: true, otherPubkey: event.otherPubkey));

    // Watch for new messages matching this pubkey
    _messageWatcher ??= _isar.dmMessageModels.watchLazy().listen((_) {
       if (!isClosed) {
         add(DmChatLoadEvent(otherPubkey: event.otherPubkey));
       }
    });

    try {
      final result = await _fetchDmUseCase.call(event.otherPubkey);
      result.fold(
        (failure) => emit(state.copyWith(
          isLoading: false,
          errorMessage: failure.toMessage(),
        )),
        (messages) => emit(state.copyWith(
          isLoading: false,
          messages: messages,
          errorMessage: null,
        ))
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onSend(DmChatSendEvent event, Emitter<DmChatState> emit) async {
    if (state.otherPubkey == null || event.content.trim().isEmpty) return;

    emit(state.copyWith(isSending: true));
    try {
      final params = SendDmParams(
        otherPubkey: state.otherPubkey!,
        content: event.content.trim(),
      );

      final result = await _sendDmUseCase.call(params);
      result.fold(
        (failure) => emit(state.copyWith(
          isSending: false,
          errorMessage: failure.toMessage(),
        )),
        (_) {
          // Success. The Isar watcher will naturally pick up the newly written 
          // unencrypted DmMessageModel and trigger a reload.
          emit(state.copyWith(isSending: false, errorMessage: null));
        }
      );
    } catch (e) {
      emit(state.copyWith(isSending: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefresh(DmChatRefreshEvent event, Emitter<DmChatState> emit) async {
    // Manually force processing of the encrypt queue
    await _getDmUseCase.call();
    if (state.otherPubkey != null) {
      add(DmChatLoadEvent(otherPubkey: state.otherPubkey!));
    }
  }

  @override
  Future<void> close() {
    _messageWatcher?.cancel();
    return super.close();
  }
}
