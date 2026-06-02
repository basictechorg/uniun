import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_message_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_join_request_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

abstract class PrivateChannelDetailEvent {}

class LoadPrivateChannelEvent extends PrivateChannelDetailEvent {
  final String groupId;
  LoadPrivateChannelEvent(this.groupId);
}

class SendPrivateChannelMessageEvent extends PrivateChannelDetailEvent {
  final String content;
  final List<String> mentionRefs;
  SendPrivateChannelMessageEvent(this.content, {this.mentionRefs = const []});
}

class ApproveJoinRequestEvent extends PrivateChannelDetailEvent {
  final String userKeyPackageB64;
  ApproveJoinRequestEvent(this.userKeyPackageB64);
}

class LeavePrivateChannelEvent extends PrivateChannelDetailEvent {}

class _PrivateChannelUpdated extends PrivateChannelDetailEvent {
  final PrivateChannelEntity? channel;
  _PrivateChannelUpdated(this.channel);
}

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
  final Map<String, ProfileEntity> profiles;
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
    this.profiles = const {},
    this.isAdmin = false,
    this.isLeft = false,
  });

  /// True once the channel is loaded but the user is still awaiting admin
  /// approval — i.e. no MLS Welcome has been received yet, so [mlsGroupId] is
  /// still empty. Admins are members by construction and are never pending.
  bool get isPendingApproval =>
      !isLoading &&
      channel != null &&
      !isAdmin &&
      channel!.mlsGroupId.isEmpty;

  PrivateChannelDetailState copyWith({
    bool? isLoading,
    bool? isApproving,
    String? errorMessage,
    PrivateChannelEntity? channel,
    List<PrivateChannelMessageEntity>? messages,
    List<PrivateChannelJoinRequestEntity>? joinRequests,
    Map<String, ProfileEntity>? profiles,
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
      profiles: profiles ?? this.profiles,
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
  final GetProfileUseCase _getProfile;
  StreamSubscription<PrivateChannelEntity?>? _channelSubscription;
  StreamSubscription<List<PrivateChannelMessageEntity>>? _messagesSubscription;
  StreamSubscription<List<PrivateChannelJoinRequestEntity>>? _joinRequestsSubscription;
  String? _activeUserPubkey;

  PrivateChannelDetailBloc(
    this._getChannel,
    this._getMessages,
    this._getJoinRequests,
    this._sendMessage,
    this._approveJoin,
    this._leaveChannel,
    this._getActiveUser,
    this._getActiveUserKeys,
    this._getProfile,
    @factoryParam String groupId,
  ) : super(PrivateChannelDetailState(groupId: groupId)) {
    on<LoadPrivateChannelEvent>(_onLoad);
    on<SendPrivateChannelMessageEvent>(_onSend);
    on<ApproveJoinRequestEvent>(_onApprove);
    on<LeavePrivateChannelEvent>(_onLeave);
    on<_PrivateChannelUpdated>((event, emit) {
      final channel = event.channel;
      if (channel == null) return; // leave/delete is handled via isLeft.
      final isAdmin =
          _activeUserPubkey != null && channel.adminPubkey == _activeUserPubkey;
      emit(state.copyWith(channel: channel, isAdmin: isAdmin));
    });
    on<_PrivateChannelMessagesUpdated>((event, emit) async {
      final profiles = await _hydrateProfiles(event.messages);
      emit(state.copyWith(messages: event.messages, profiles: profiles));
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
      _activeUserPubkey = user.pubkeyHex;

      final channel = await _getChannel.execute(event.groupId);
      if (channel == null) throw Exception('Channel not found locally.');

      final isAdmin = channel.adminPubkey == user.pubkeyHex;

      emit(state.copyWith(isLoading: false, channel: channel, isAdmin: isAdmin));

      await _channelSubscription?.cancel();
      await _messagesSubscription?.cancel();
      await _joinRequestsSubscription?.cancel();

      // Watch the channel so the UI flips from "pending approval" to the chat
      // the moment the admin's MLS Welcome populates mlsGroupId.
      _channelSubscription = _getChannel.watch(event.groupId).listen(
        (channel) => add(_PrivateChannelUpdated(channel)),
      );

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
        mentionRefs: event.mentionRefs,
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

  Future<Map<String, ProfileEntity>> _hydrateProfiles(
    List<PrivateChannelMessageEntity> messages,
  ) async {
    final profiles = Map<String, ProfileEntity>.from(state.profiles);
    final missing = messages
        .map((m) => m.senderPubkey)
        .toSet()
        .where((k) => !profiles.containsKey(k));
    for (final pubkey in missing) {
      final r = await _getProfile.call(pubkey);
      r.fold((_) {}, (p) => profiles[pubkey] = p);
    }
    return profiles;
  }

  @override
  Future<void> close() async {
    await _channelSubscription?.cancel();
    await _messagesSubscription?.cancel();
    await _joinRequestsSubscription?.cancel();
    return super.close();
  }
}

