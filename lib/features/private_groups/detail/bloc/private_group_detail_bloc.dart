import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_join_request_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/unread_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

abstract class PrivateGroupDetailEvent {}

/// A message scrolled past the viewport — delete its unread row.
class MarkPrivateGroupMessageSeenEvent extends PrivateGroupDetailEvent {
  final String eventId;
  MarkPrivateGroupMessageSeenEvent(this.eventId);
}

/// The user reached the end of the list — mark the whole group read.
class MarkAllPrivateGroupSeenEvent extends PrivateGroupDetailEvent {}

class LoadPrivateGroupEvent extends PrivateGroupDetailEvent {
  final String groupId;
  LoadPrivateGroupEvent(this.groupId);
}

class SendPrivateGroupMessageEvent extends PrivateGroupDetailEvent {
  final String content;
  final List<String> mentionRefs;
  final List<MediaBlobEntity> attachments;
  SendPrivateGroupMessageEvent(
    this.content, {
    this.mentionRefs = const [],
    this.attachments = const [],
  });
}

class ApproveJoinRequestEvent extends PrivateGroupDetailEvent {
  final String userKeyPackageB64;
  ApproveJoinRequestEvent(this.userKeyPackageB64);
}

class LeavePrivateGroupEvent extends PrivateGroupDetailEvent {}

class _PrivateGroupUpdated extends PrivateGroupDetailEvent {
  final PrivateGroupEntity? group;
  _PrivateGroupUpdated(this.group);
}

class _PrivateGroupMessagesUpdated extends PrivateGroupDetailEvent {
  final List<NoteEntity> messages;
  _PrivateGroupMessagesUpdated(this.messages);
}

class _PrivateGroupJoinRequestsUpdated extends PrivateGroupDetailEvent {
  final List<PrivateGroupJoinRequestEntity> joinRequests;
  _PrivateGroupJoinRequestsUpdated(this.joinRequests);
}

class PrivateGroupDetailState {
  final bool isLoading;
  final bool isApproving;
  final String? errorMessage;
  final String groupId;
  final PrivateGroupEntity? group;
  final List<NoteEntity> messages;
  final List<PrivateGroupJoinRequestEntity> joinRequests;
  final Map<String, ProfileEntity> profiles;
  final bool isAdmin;
  final bool isLeft;

  PrivateGroupDetailState({
    this.isLoading = false,
    this.isApproving = false,
    this.errorMessage,
    required this.groupId,
    this.group,
    this.messages = const [],
    this.joinRequests = const [],
    this.profiles = const {},
    this.isAdmin = false,
    this.isLeft = false,
  });

  /// True once the group is loaded but the user is still awaiting admin
  /// approval — i.e. no MLS Welcome has been received yet, so [mlsGroupId] is
  /// still empty. Admins are members by construction and are never pending.
  bool get isPendingApproval =>
      !isLoading &&
      group != null &&
      !isAdmin &&
      group!.mlsGroupId.isEmpty;

  PrivateGroupDetailState copyWith({
    bool? isLoading,
    bool? isApproving,
    String? errorMessage,
    PrivateGroupEntity? group,
    List<NoteEntity>? messages,
    List<PrivateGroupJoinRequestEntity>? joinRequests,
    Map<String, ProfileEntity>? profiles,
    bool? isAdmin,
    bool? isLeft,
  }) {
    return PrivateGroupDetailState(
      isLoading: isLoading ?? this.isLoading,
      isApproving: isApproving ?? this.isApproving,
      errorMessage: errorMessage,
      groupId: groupId,
      group: group ?? this.group,
      messages: messages ?? this.messages,
      joinRequests: joinRequests ?? this.joinRequests,
      profiles: profiles ?? this.profiles,
      isAdmin: isAdmin ?? this.isAdmin,
      isLeft: isLeft ?? this.isLeft,
    );
  }
}

@injectable
class PrivateGroupDetailBloc extends Bloc<PrivateGroupDetailEvent, PrivateGroupDetailState> {
  final GetPrivateGroupEntityUsecase _getGroup;
  final GetPrivateGroupMessagesUsecase _getMessages;
  final GetPrivateGroupJoinRequestsUsecase _getJoinRequests;
  final SendPrivateGroupMessageUsecase _sendMessage;
  final ApprovePrivateGroupJoinUsecase _approveJoin;
  final LeavePrivateGroupUsecase _leaveGroup;
  final GetActiveUserUseCase _getActiveUser;
  final GetActiveUserKeysUseCase _getActiveUserKeys;
  final GetProfileUseCase _getProfile;
  final MarkUnreadSeenUseCase _markUnreadSeen;
  final MarkPrivateGroupSeenUseCase _markPrivateGroupSeen;
  final Set<String> _markedThisSession = <String>{};
  StreamSubscription<PrivateGroupEntity?>? _groupSubscription;
  StreamSubscription<List<NoteEntity>>? _messagesSubscription;
  StreamSubscription<List<PrivateGroupJoinRequestEntity>>? _joinRequestsSubscription;
  String? _activeUserPubkey;

  PrivateGroupDetailBloc(
    this._getGroup,
    this._getMessages,
    this._getJoinRequests,
    this._sendMessage,
    this._approveJoin,
    this._leaveGroup,
    this._getActiveUser,
    this._getActiveUserKeys,
    this._getProfile,
    this._markUnreadSeen,
    this._markPrivateGroupSeen,
    @factoryParam String groupId,
  ) : super(PrivateGroupDetailState(groupId: groupId)) {
    on<LoadPrivateGroupEvent>(_onLoad);
    on<SendPrivateGroupMessageEvent>(_onSend);
    on<ApproveJoinRequestEvent>(_onApprove);
    on<LeavePrivateGroupEvent>(_onLeave);
    on<MarkPrivateGroupMessageSeenEvent>(_onMarkSeen);
    on<MarkAllPrivateGroupSeenEvent>(_onMarkAllSeen);
    on<_PrivateGroupUpdated>((event, emit) {
      final group = event.group;
      if (group == null) return; // leave/delete is handled via isLeft.
      final isAdmin =
          _activeUserPubkey != null && group.adminPubkey == _activeUserPubkey;
      emit(state.copyWith(group: group, isAdmin: isAdmin));
    });
    on<_PrivateGroupMessagesUpdated>((event, emit) async {
      final profiles = await _hydrateProfiles(event.messages);
      emit(state.copyWith(messages: event.messages, profiles: profiles));
    });
    on<_PrivateGroupJoinRequestsUpdated>((event, emit) {
      emit(state.copyWith(joinRequests: _dedupBySender(event.joinRequests)));
    });

    add(LoadPrivateGroupEvent(groupId));
  }

  Future<void> _onMarkSeen(
    MarkPrivateGroupMessageSeenEvent event,
    Emitter<PrivateGroupDetailState> emit,
  ) async {
    if (!_markedThisSession.add(event.eventId)) return;
    await _markUnreadSeen.call(event.eventId);
  }

  Future<void> _onMarkAllSeen(
    MarkAllPrivateGroupSeenEvent event,
    Emitter<PrivateGroupDetailState> emit,
  ) async {
    await _markPrivateGroupSeen.call(state.groupId);
  }

  Future<void> _onLoad(LoadPrivateGroupEvent event, Emitter<PrivateGroupDetailState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final userResult = await _getActiveUser.call();
      final user = userResult.fold((_) => null, (u) => u);
      if (user == null) throw Exception('No active user');
      _activeUserPubkey = user.pubkeyHex;

      final group = await _getGroup.execute(event.groupId);
      if (group == null) throw Exception('Group not found locally.');

      final isAdmin = group.adminPubkey == user.pubkeyHex;

      emit(state.copyWith(isLoading: false, group: group, isAdmin: isAdmin));

      await _groupSubscription?.cancel();
      await _messagesSubscription?.cancel();
      await _joinRequestsSubscription?.cancel();

      // Watch the group so the UI flips from "pending approval" to the chat
      // the moment the admin's MLS Welcome populates mlsGroupId.
      _groupSubscription = _getGroup.watch(event.groupId).listen(
        (group) => add(_PrivateGroupUpdated(group)),
      );

      _messagesSubscription = _getMessages.execute(event.groupId).listen(
        (messages) => add(_PrivateGroupMessagesUpdated(messages)),
      );
      if (isAdmin) {
        _joinRequestsSubscription = _getJoinRequests.execute(event.groupId).listen(
          (joinRequests) => add(_PrivateGroupJoinRequestsUpdated(joinRequests)),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onSend(SendPrivateGroupMessageEvent event, Emitter<PrivateGroupDetailState> emit) async {
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
        attachments: event.attachments,
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to send message: $e'));
    }
  }

  Future<void> _onApprove(ApproveJoinRequestEvent event, Emitter<PrivateGroupDetailState> emit) async {
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

  Future<void> _onLeave(LeavePrivateGroupEvent event, Emitter<PrivateGroupDetailState> emit) async {
    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);
      if (keys == null) return;

      await _leaveGroup.execute(
        groupId: state.groupId,
        authorPubkey: keys.pubkeyHex,
        privkeyHex: keys.privkeyHex,
      );

      emit(state.copyWith(isLeft: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to leave group: $e'));
    }
  }

  /// Collapses multiple outstanding requests from the same member to their
  /// latest one. A member may tap "request to join" more than once; each tap is
  /// a distinct row sharing one MLS signature key, so showing (and approving)
  /// more than one would trigger a duplicate-signature error.
  List<PrivateGroupJoinRequestEntity> _dedupBySender(
    List<PrivateGroupJoinRequestEntity> requests,
  ) {
    final bySender = <String, PrivateGroupJoinRequestEntity>{};
    for (final request in requests) {
      final existing = bySender[request.senderPubkey];
      if (existing == null || request.timestamp.isAfter(existing.timestamp)) {
        bySender[request.senderPubkey] = request;
      }
    }
    return bySender.values.toList();
  }

  Future<Map<String, ProfileEntity>> _hydrateProfiles(
    List<NoteEntity> messages,
  ) async {
    final profiles = Map<String, ProfileEntity>.from(state.profiles);
    final missing = messages
        .map((m) => m.authorPubkey)
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
    await _groupSubscription?.cancel();
    await _messagesSubscription?.cancel();
    await _joinRequestsSubscription?.cancel();
    return super.close();
  }
}

