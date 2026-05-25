import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';

class ChannelThreadState {
  const ChannelThreadState({
    this.root,
    this.parent,
    this.mentionedMessages = const [],
    this.replies = const [],
    this.profiles = const {},
    this.savedIds = const {},
    this.isLoading = false,
    this.isSending = false,
  });

  final ChannelMessageEntity? root;
  /// Parent message — non-null when root is itself a reply.
  final ChannelMessageEntity? parent;
  /// Mention refs (eTagRefs minus channelId/replyToEventId), shown above root.
  final List<ChannelMessageEntity> mentionedMessages;
  final List<ChannelMessageEntity> replies;
  final Map<String, ProfileEntity> profiles;
  final Set<String> savedIds;
  final bool isLoading;
  final bool isSending;

  ChannelThreadState copyWith({
    ChannelMessageEntity? root,
    ChannelMessageEntity? parent,
    List<ChannelMessageEntity>? mentionedMessages,
    List<ChannelMessageEntity>? replies,
    Map<String, ProfileEntity>? profiles,
    Set<String>? savedIds,
    bool? isLoading,
    bool? isSending,
  }) {
    return ChannelThreadState(
      root: root ?? this.root,
      parent: parent ?? this.parent,
      mentionedMessages: mentionedMessages ?? this.mentionedMessages,
      replies: replies ?? this.replies,
      profiles: profiles ?? this.profiles,
      savedIds: savedIds ?? this.savedIds,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}
