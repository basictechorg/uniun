import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_bloc.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_event.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/get_channel_messages_usecase.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'channel_thread_event.dart';
import 'channel_thread_state.dart';

class ChannelThreadBloc extends Bloc<ChannelThreadEvent, ChannelThreadState> {
  ChannelThreadBloc() : super(const ChannelThreadState()) {
    on<LoadChannelThreadEvent>(_onLoad);
    on<SaveChannelMessageEvent>(_onSave);
    on<UnsaveChannelMessageEvent>(_onUnsave);
  }

  Future<void> _onLoad(
    LoadChannelThreadEvent event,
    Emitter<ChannelThreadState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    final rootResult =
        await getIt<GetChannelMessageByIdUseCase>().call(event.messageId);

    final root = rootResult.fold((_) => null, (m) => m);
    if (root == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    final repliesResult =
        await getIt<GetChannelMessageRepliesUseCase>().call(event.messageId);
    final replies =
        repliesResult.fold((_) => <ChannelMessageEntity>[], (r) => r);

    ChannelMessageEntity? parent;
    if (root.replyToEventId != null) {
      final parentResult =
          await getIt<GetChannelMessageByIdUseCase>().call(root.replyToEventId!);
      parent = parentResult.fold((_) => null, (m) => m);
    }

    final mentionIds = root.eTagRefs
        .where((id) => id != root.channelId && id != root.replyToEventId)
        .toList();
    final mentionedMessages = <ChannelMessageEntity>[];
    for (final id in mentionIds) {
      final r = await getIt<GetChannelMessageByIdUseCase>().call(id);
      r.fold((_) => null, (m) { if (m != null) mentionedMessages.add(m); });
    }

    final all = [if (parent != null) parent, ...mentionedMessages, root, ...replies];
    final profiles = await _loadProfiles(all);
    final savedIds = await _loadSavedIds(all);

    emit(state.copyWith(
      isLoading: false,
      root: root,
      parent: parent,
      mentionedMessages: mentionedMessages,
      replies: replies,
      profiles: profiles,
      savedIds: savedIds,
    ));
  }

  void _onSave(SaveChannelMessageEvent event, Emitter<ChannelThreadState> emit) {
    emit(state.copyWith(savedIds: {...state.savedIds, event.messageId}));
  }

  void _onUnsave(UnsaveChannelMessageEvent event, Emitter<ChannelThreadState> emit) {
    emit(state.copyWith(savedIds: state.savedIds.difference({event.messageId})));
  }

  // Keep convenience methods so callers don't need to know about events for save/unsave
  void saveMessage(ChannelMessageEntity msg, ChannelFeedBloc parent) {
    parent.add(SaveChannelFeedMessageEvent(msg));
    add(SaveChannelMessageEvent(msg.id));
  }

  void unsaveMessage(String id, ChannelFeedBloc parent) {
    parent.add(UnsaveChannelFeedMessageEvent(id));
    add(UnsaveChannelMessageEvent(id));
  }

  Future<Map<String, ProfileEntity>> _loadProfiles(
      List<ChannelMessageEntity> messages) async {
    final pubkeys = messages.map((m) => m.authorPubkey).toSet();
    final profiles = <String, ProfileEntity>{};
    for (final pk in pubkeys) {
      final r = await getIt<GetProfileUseCase>().call(pk);
      r.fold((_) => null, (p) => profiles[pk] = p);
    }
    return profiles;
  }

  Future<Set<String>> _loadSavedIds(
      List<ChannelMessageEntity> messages) async {
    final saved = <String>{};
    for (final msg in messages) {
      final r = await getIt<IsSavedNoteUseCase>().call(msg.id);
      r.fold((_) => null, (isSaved) {
        if (isSaved) saved.add(msg.id);
      });
    }
    return saved;
  }
}
