import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';

enum ChannelFeedStatus { initial, loading, loaded, error }

class ChannelFeedState {
  const ChannelFeedState({
    this.status = ChannelFeedStatus.initial,
    this.channel,
    this.messages = const [],
    this.profiles = const {},
    this.savedIds = const {},
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
  });

  final ChannelFeedStatus status;
  final ChannelEntity? channel;

  /// Messages in oldest→newest order (ready for chat-style display).
  final List<ChannelMessageEntity> messages;

  /// pubkeyHex → ProfileEntity (for author display names / avatars).
  final Map<String, ProfileEntity> profiles;

  /// eventIds the active user has saved/bookmarked.
  final Set<String> savedIds;

  final bool isLoading;
  final bool isSending;
  final String? errorMessage;

  ChannelFeedState copyWith({
    ChannelFeedStatus? status,
    ChannelEntity? channel,
    List<ChannelMessageEntity>? messages,
    Map<String, ProfileEntity>? profiles,
    Set<String>? savedIds,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
  }) {
    return ChannelFeedState(
      status: status ?? this.status,
      channel: channel ?? this.channel,
      messages: messages ?? this.messages,
      profiles: profiles ?? this.profiles,
      savedIds: savedIds ?? this.savedIds,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
