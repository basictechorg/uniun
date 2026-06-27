import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';
import 'package:uniun/domain/usecases/get_group_by_id_usecase.dart';
import 'package:uniun/domain/usecases/get_group_messages_usecase.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/unread_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'group_feed_event.dart';
import 'group_feed_state.dart';

/// Messages loaded per upward / downward pagination step.
const int _kGroupPageSize = 10;

class GroupFeedBloc extends Bloc<GroupFeedEvent, GroupFeedState> {
  final Set<String> _markedThisSession = <String>{};

  GroupFeedBloc() : super(const GroupFeedState()) {
    on<LoadGroupFeedEvent>(_onLoad);
    on<LoadOlderGroupMessagesEvent>(_onLoadOlder);
    on<LoadNewerGroupMessagesEvent>(_onLoadNewer);
    on<SendGroupMessageEvent>(_onSend);
    on<SaveGroupFeedMessageEvent>(_onSave);
    on<UnsaveGroupFeedMessageEvent>(_onUnsave);
    on<MarkGroupMessageSeenEvent>(_onMarkSeen);
    on<MarkAllGroupSeenEvent>(_onMarkAllSeen);
  }

  Future<void> _onMarkSeen(
    MarkGroupMessageSeenEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    if (!_markedThisSession.add(event.eventId)) return;
    await getIt<MarkUnreadSeenUseCase>().call(event.eventId);
  }

  Future<void> _onMarkAllSeen(
    MarkAllGroupSeenEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    await getIt<MarkGroupSeenUseCase>().call(event.groupId);
  }

  /// Initial bidirectional load: the newest page of already-read messages above
  /// the read→unread boundary, plus the oldest page of unread messages below it.
  /// The list opens anchored at that boundary (the last-seen note).
  Future<void> _onLoad(
    LoadGroupFeedEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    if (!event.silent) {
      emit(state.copyWith(status: GroupFeedStatus.loading, isLoading: true));
    }

    final groupResult = await getIt<GetGroupByIdUseCase>().call(event.groupId);
    final group = groupResult.fold((_) => null, (c) => c);
    if (group == null) {
      emit(state.copyWith(
        status: GroupFeedStatus.error,
        isLoading: false,
        errorMessage: 'Group not found.',
      ));
      return;
    }

    // The boundary is the oldest unread message's timestamp. Null → all read,
    // so the feed opens at the bottom (newest) like a normal chat.
    final boundaryTime = (await getIt<GetGroupOldestUnreadTimeUseCase>()
            .call(event.groupId))
        .fold((_) => null, (t) => t);

    // Top section: newest page of messages strictly before the boundary.
    final topRaw = (await getIt<GetGroupMessagesUseCase>().call(
      GetGroupMessagesInput(
        groupId: event.groupId,
        limit: _kGroupPageSize,
        before: boundaryTime,
      ),
    ))
        .fold((_) => <NoteEntity>[], (m) => m); // newest-first
    final top = topRaw.reversed.toList(); // ascending

    // Bottom section: oldest page of unread messages at/after the boundary.
    var bottom = <NoteEntity>[];
    if (boundaryTime != null) {
      bottom = (await getIt<GetGroupMessagesAfterUseCase>().call(
        GetGroupMessagesAfterInput(
          groupId: event.groupId,
          after: boundaryTime,
          inclusive: true,
          limit: _kGroupPageSize,
        ),
      ))
          .fold((_) => <NoteEntity>[], (m) => m); // ascending
    }

    final messages = [...top, ...bottom];
    final profiles = await _loadProfiles(messages);
    final savedIds = await _loadSavedIds(messages);

    emit(state.copyWith(
      status: GroupFeedStatus.loaded,
      group: group,
      messages: messages,
      boundaryIndex: top.length,
      openedAtMiddle: bottom.isNotEmpty,
      profiles: profiles,
      savedIds: savedIds,
      hasMoreOlder: top.length == _kGroupPageSize,
      hasMoreUnread: bottom.length == _kGroupPageSize,
      isLoading: false,
    ));
  }

  /// Scrolling up: prepend the next older page of read messages.
  Future<void> _onLoadOlder(
    LoadOlderGroupMessagesEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    if (state.isLoadingOlder || !state.hasMoreOlder || state.messages.isEmpty) {
      return;
    }
    emit(state.copyWith(isLoadingOlder: true));

    final older = ((await getIt<GetGroupMessagesUseCase>().call(
      GetGroupMessagesInput(
        groupId: event.groupId,
        limit: _kGroupPageSize,
        before: state.messages.first.created,
      ),
    ))
            .fold((_) => <NoteEntity>[], (m) => m))
        .reversed
        .toList(); // ascending

    final existing = state.messages.map((m) => m.id).toSet();
    final fresh = older.where((m) => !existing.contains(m.id)).toList();
    if (fresh.isEmpty) {
      emit(state.copyWith(isLoadingOlder: false, hasMoreOlder: false));
      return;
    }

    emit(state.copyWith(
      messages: [...fresh, ...state.messages],
      boundaryIndex: state.boundaryIndex + fresh.length,
      profiles: await _mergeProfiles(fresh),
      savedIds: await _mergeSaved(fresh),
      hasMoreOlder: older.length == _kGroupPageSize,
      isLoadingOlder: false,
    ));
  }

  /// Scrolling down (or bottom pull-to-refresh): append the next page of newer
  /// messages. [isRefresh] re-checks even when no more were previously found,
  /// to surface unread messages the Gateway synced after open.
  Future<void> _onLoadNewer(
    LoadNewerGroupMessagesEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    if (state.isLoadingUnread || state.messages.isEmpty) return;
    if (!event.isRefresh && !state.hasMoreUnread) return;
    emit(state.copyWith(isLoadingUnread: true));

    // Inclusive + dedupe so messages sharing the last loaded timestamp are not
    // skipped over.
    final newer = (await getIt<GetGroupMessagesAfterUseCase>().call(
      GetGroupMessagesAfterInput(
        groupId: event.groupId,
        after: state.messages.last.created,
        inclusive: true,
        limit: _kGroupPageSize,
      ),
    ))
        .fold((_) => <NoteEntity>[], (m) => m); // ascending

    final existing = state.messages.map((m) => m.id).toSet();
    final fresh = newer.where((m) => !existing.contains(m.id)).toList();
    if (fresh.isEmpty) {
      emit(state.copyWith(isLoadingUnread: false, hasMoreUnread: false));
      return;
    }

    emit(state.copyWith(
      messages: [...state.messages, ...fresh],
      profiles: await _mergeProfiles(fresh),
      savedIds: await _mergeSaved(fresh),
      hasMoreUnread: newer.length == _kGroupPageSize,
      isLoadingUnread: false,
    ));
  }

  Future<void> _onSend(
    SendGroupMessageEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    if (event.content.trim().isEmpty && event.attachments.isEmpty) return;
    emit(state.copyWith(isSending: true, errorMessage: null));

    final keysResult = await getIt<GetActiveUserKeysUseCase>().call();
    final keys = keysResult.fold((_) => null, (k) => k);
    if (keys == null) {
      emit(state.copyWith(isSending: false, errorMessage: 'Not logged in.'));
      return;
    }

    final result = await getIt<CreateGroupMessageUseCase>().call(
      CreateGroupMessageInput(
        groupId: event.groupId,
        content: event.content.trim(),
        privateKey: keys.privkeyHex,
        replyToEventId: event.replyToEventId,
        mentionRefs: event.mentionRefs,
        attachments: event.attachments,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        isSending: false,
        errorMessage: failure.toMessage(),
      )),
      (message) {
        // Append the sent message at the bottom (newest). No reload — that
        // would reset the boundary anchor and the paginated range.
        emit(state.copyWith(
          isSending: false,
          messages: [...state.messages, message],
        ));
      },
    );
  }

  Future<void> _onSave(
    SaveGroupFeedMessageEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    final result = await getIt<SaveNoteUseCase>().call(event.message);
    result.fold(
      (_) => null,
      (_) => emit(state.copyWith(savedIds: {...state.savedIds, event.message.id})),
    );
  }

  Future<void> _onUnsave(
    UnsaveGroupFeedMessageEvent event,
    Emitter<GroupFeedState> emit,
  ) async {
    final result = await getIt<UnsaveNoteUseCase>().call(event.messageId);
    result.fold(
      (_) => null,
      (_) => emit(state.copyWith(
        savedIds: state.savedIds.difference({event.messageId}),
      )),
    );
  }

  Future<Map<String, ProfileEntity>> _loadProfiles(
      List<NoteEntity> messages) async {
    final pubkeys = messages.map((m) => m.authorPubkey).toSet();
    final profiles = <String, ProfileEntity>{};
    for (final pk in pubkeys) {
      final result = await getIt<GetProfileUseCase>().call(pk);
      result.fold((_) => null, (p) => profiles[pk] = p);
    }
    return profiles;
  }

  Future<Set<String>> _loadSavedIds(
      List<NoteEntity> messages) async {
    final saved = <String>{};
    for (final msg in messages) {
      final result = await getIt<IsSavedNoteUseCase>().call(msg.id);
      result.fold((_) => null, (isSaved) {
        if (isSaved) saved.add(msg.id);
      });
    }
    return saved;
  }

  /// Loads profiles for newly-paginated [added] messages whose author is not
  /// already in the current map, merged onto the existing profiles.
  Future<Map<String, ProfileEntity>> _mergeProfiles(
      List<NoteEntity> added) async {
    final result = Map<String, ProfileEntity>.from(state.profiles);
    final missing = added
        .map((m) => m.authorPubkey)
        .toSet()
        .where((pk) => !result.containsKey(pk));
    for (final pk in missing) {
      final r = await getIt<GetProfileUseCase>().call(pk);
      r.fold((_) => null, (p) => result[pk] = p);
    }
    return result;
  }

  /// Folds the saved/bookmarked state of newly-paginated [added] messages into
  /// the existing set.
  Future<Set<String>> _mergeSaved(List<NoteEntity> added) async {
    final result = Set<String>.from(state.savedIds);
    for (final msg in added) {
      final r = await getIt<IsSavedNoteUseCase>().call(msg.id);
      r.fold((_) => null, (isSaved) {
        if (isSaved) result.add(msg.id);
      });
    }
    return result;
  }
}
