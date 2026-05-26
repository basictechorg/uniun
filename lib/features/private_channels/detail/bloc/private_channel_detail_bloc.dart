import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_message_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_join_request_entity.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

abstract class PrivateChannelDetailEvent {}

class LoadPrivateChannelEvent extends PrivateChannelDetailEvent {
  final String groupId;
  LoadPrivateChannelEvent(this.groupId);
}

class SendPrivateChannelMessageEvent extends PrivateChannelDetailEvent {
  final String content;
  SendPrivateChannelMessageEvent(this.content);
}

class ApproveJoinRequestEvent extends PrivateChannelDetailEvent {
  final String userKeyPackageB64;
  ApproveJoinRequestEvent(this.userKeyPackageB64);
}

class LeavePrivateChannelEvent extends PrivateChannelDetailEvent {}

class _PrivateChannelMessagesUpdated extends PrivateChannelDetailEvent {
  final List<PrivateChannelMessageEntity> messages;
  _PrivateChannelMessagesUpdated(this.messages);
}

class _PrivateChannelJoinRequestsUpdated extends PrivateChannelDetailEvent {
  final List<PrivateChannelJoinRequestEntity> joinRequests;
  _PrivateChannelJoinRequestsUpdated(this.joinRequests);
}

class PrivateChannelDetailState {
  final bool isLoading;
  final bool isApproving;
  final String? errorMessage;
  final String groupId;
  final PrivateChannelEntity? channel;
  final List<PrivateChannelMessageEntity> messages;
  final List<PrivateChannelJoinRequestEntity> joinRequests;
  final bool isAdmin;
  final bool isLeft;

  PrivateChannelDetailState({
    this.isLoading = false,
    this.isApproving = false,
    this.errorMessage,
    required this.groupId,
    this.channel,
    this.messages = const [],
    this.joinRequests = const [],
    this.isAdmin = false,
    this.isLeft = false,
  });

  PrivateChannelDetailState copyWith({
    bool? isLoading,
    bool? isApproving,
    String? errorMessage,
    PrivateChannelEntity? channel,
    List<PrivateChannelMessageEntity>? messages,
    List<PrivateChannelJoinRequestEntity>? joinRequests,
    bool? isAdmin,
    bool? isLeft,
  }) {
    return PrivateChannelDetailState(
      isLoading: isLoading ?? this.isLoading,
      isApproving: isApproving ?? this.isApproving,
      errorMessage: errorMessage,
      groupId: groupId,
      channel: channel ?? this.channel,
      messages: messages ?? this.messages,
      joinRequests: joinRequests ?? this.joinRequests,
      isAdmin: isAdmin ?? this.isAdmin,
      isLeft: isLeft ?? this.isLeft,
    );
  }
}

@injectable
class PrivateChannelDetailBloc extends Bloc<PrivateChannelDetailEvent, PrivateChannelDetailState> {
  final GetPrivateChannelEntityUsecase _getChannel;
  final GetPrivateChannelMessagesUsecase _getMessages;
  final GetPrivateChannelJoinRequestsUsecase _getJoinRequests;
  final SendPrivateChannelMessageUsecase _sendMessage;
  final ApprovePrivateChannelJoinUsecase _approveJoin;
  final LeavePrivateChannelUsecase _leaveChannel;
  final GetActiveUserUseCase _getActiveUser;
  final GetActiveUserKeysUseCase _getActiveUserKeys;
  StreamSubscription<List<PrivateChannelMessageEntity>>? _messagesSubscription;
  StreamSubscription<List<PrivateChannelJoinRequestEntity>>? _joinRequestsSubscription;

  PrivateChannelDetailBloc(
    this._getChannel,
    this._getMessages,
    this._getJoinRequests,
    this._sendMessage,
    this._approveJoin,
    this._leaveChannel,
    this._getActiveUser,
    this._getActiveUserKeys,
    @factoryParam String groupId,
  ) : super(PrivateChannelDetailState(groupId: groupId)) {
    on<LoadPrivateChannelEvent>(_onLoad);
    on<SendPrivateChannelMessageEvent>(_onSend);
    on<ApproveJoinRequestEvent>(_onApprove);
    on<LeavePrivateChannelEvent>(_onLeave);
    on<_PrivateChannelMessagesUpdated>((event, emit) {
      emit(state.copyWith(messages: event.messages));
    });
    on<_PrivateChannelJoinRequestsUpdated>((event, emit) {
      emit(state.copyWith(joinRequests: event.joinRequests));
    });

    add(LoadPrivateChannelEvent(groupId));
  }

  Future<void> _onLoad(LoadPrivateChannelEvent event, Emitter<PrivateChannelDetailState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final userResult = await _getActiveUser.call();
      final user = userResult.fold((_) => null, (u) => u);
      if (user == null) throw Exception('No active user');

      final channel = await _getChannel.execute(event.groupId);
      if (channel == null) throw Exception('Channel not found locally.');

      final isAdmin = channel.adminPubkey == user.pubkeyHex;

      emit(state.copyWith(isLoading: false, channel: channel, isAdmin: isAdmin));

      await _messagesSubscription?.cancel();
      await _joinRequestsSubscription?.cancel();

      _messagesSubscription = _getMessages.execute(event.groupId).listen(
        (messages) => add(_PrivateChannelMessagesUpdated(messages)),
      );
      if (isAdmin) {
        _joinRequestsSubscription = _getJoinRequests.execute(event.groupId).listen(
          (joinRequests) => add(_PrivateChannelJoinRequestsUpdated(joinRequests)),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onSend(SendPrivateChannelMessageEvent event, Emitter<PrivateChannelDetailState> emit) async {
    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);
      if (keys == null) return;

      await _sendMessage.execute(
        groupId: state.groupId,
        content: event.content,
        authorPubkey: keys.pubkeyHex,
        privkeyHex: keys.privkeyHex,
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to send message: $e'));
    }
  }

  Future<void> _onApprove(ApproveJoinRequestEvent event, Emitter<PrivateChannelDetailState> emit) async {
    if (state.isApproving) return;
    emit(state.copyWith(isApproving: true, errorMessage: null));

    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);
      if (keys == null) {
        emit(state.copyWith(isApproving: false));
        return;
      }

      await _approveJoin.execute(
        groupId: state.groupId,
        userKeyPackageB64: event.userKeyPackageB64,
        adminPrivkeyHex: keys.privkeyHex,
      );
      emit(state.copyWith(isApproving: false));
    } catch (e) {
      emit(state.copyWith(isApproving: false, errorMessage: 'Failed to approve: $e'));
    }
  }

  Future<void> _onLeave(LeavePrivateChannelEvent event, Emitter<PrivateChannelDetailState> emit) async {
    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);
      if (keys == null) return;

      await _leaveChannel.execute(
        groupId: state.groupId,
        authorPubkey: keys.pubkeyHex,
        privkeyHex: keys.privkeyHex,
      );

      emit(state.copyWith(isLeft: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to leave channel: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _messagesSubscription?.cancel();
    await _joinRequestsSubscription?.cancel();
    return super.close();
  }
}

