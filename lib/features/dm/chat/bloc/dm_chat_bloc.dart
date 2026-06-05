import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/unread_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

part 'dm_chat_event.dart';
part 'dm_chat_state.dart';

@injectable
class DmChatBloc extends Bloc<DmChatEvent, DmChatState> {
  final FetchDmUseCase _fetchDmUseCase;
  final SendDmUseCase _sendDmUseCase;
  final GetDmUseCase _getDmUseCase;
  final GetProfileUseCase _getProfileUseCase;
  final GetActiveUserProfileUseCase _getActiveUserProfileUseCase;
  final MarkUnreadSeenUseCase _markUnreadSeenUseCase;
  final MarkConversationSeenUseCase _markConversationSeenUseCase;
  final Isar _isar;
  StreamSubscription<void>? _messageWatcher;
  final Set<String> _markedThisSession = <String>{};

  DmChatBloc(
    this._fetchDmUseCase,
    this._sendDmUseCase,
    this._getDmUseCase,
    this._getProfileUseCase,
    this._getActiveUserProfileUseCase,
    this._markUnreadSeenUseCase,
    this._markConversationSeenUseCase,
    this._isar,
  ) : super(const DmChatState()) {
    on<DmChatLoadEvent>(_onLoad);
    on<DmChatSendEvent>(_onSend);
    on<DmChatRefreshEvent>(_onRefresh);
    on<DmChatMarkSeenEvent>(_onMarkSeen);
    on<DmChatMarkAllSeenEvent>(_onMarkAllSeen);
  }

  Future<void> _onMarkSeen(
    DmChatMarkSeenEvent event,
    Emitter<DmChatState> emit,
  ) async {
    if (!_markedThisSession.add(event.eventId)) return;
    await _markUnreadSeenUseCase.call(event.eventId);
  }

  Future<void> _onMarkAllSeen(
    DmChatMarkAllSeenEvent event,
    Emitter<DmChatState> emit,
  ) async {
    final otherPubkey = state.otherPubkey;
    if (otherPubkey == null) return;
    final conv = await _isar.dmConversationModels
        .where()
        .otherPubkeyEqualTo(otherPubkey)
        .findFirst();
    if (conv != null) {
      await _markConversationSeenUseCase.call(conv.id);
    }
  }

  Future<void> _onLoad(DmChatLoadEvent event, Emitter<DmChatState> emit) async {
    emit(state.copyWith(isLoading: true, otherPubkey: event.otherPubkey));

    // Watch for new messages matching this pubkey
    _messageWatcher ??= _isar.noteModels.watchLazy().listen((_) {
       if (!isClosed) {
         add(DmChatLoadEvent(otherPubkey: event.otherPubkey));
       }
    });

    try {
      final result = await _fetchDmUseCase.call(event.otherPubkey);
      await result.fold(
        (failure) async => emit(state.copyWith(
          isLoading: false,
          errorMessage: failure.toMessage(),
        )),
        (messages) async {
          final profiles = await _loadProfiles(event.otherPubkey);
          emit(state.copyWith(
            isLoading: false,
            messages: messages,
            profiles: profiles,
            errorMessage: null,
          ));
        },
      );
    } catch (e, st) {
      debugPrint('DM_LOAD_ERROR: $e\n$st');
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
        mentionRefs: event.mentionRefs,
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
    } catch (e, st) {
      debugPrint('DM_SEND_ERROR: $e\n$st');
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

  /// A DM has exactly two participants: the active user and [otherPubkey].
  /// Resolve those two profiles instead of scanning every message author.
  Future<Map<String, ProfileEntity>> _loadProfiles(String otherPubkey) async {
    final pubkeys = <String>{otherPubkey};
    final me = await _getActiveUserProfileUseCase.call();
    me.fold((_) => null, (p) => pubkeys.add(p.pubkeyHex));

    final profiles = <String, ProfileEntity>{};
    for (final pk in pubkeys) {
      final result = await _getProfileUseCase.call(pk);
      result.fold((_) => null, (p) => profiles[pk] = p);
    }
    return profiles;
  }

  @override
  Future<void> close() {
    _messageWatcher?.cancel();
    return super.close();
  }
}
