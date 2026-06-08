import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';

enum ChannelFeedStatus { initial, loading, loaded, error }

class ChannelFeedState {
  const ChannelFeedState({
    this.status = ChannelFeedStatus.initial,
    this.channel,
    this.messages = const [],
    this.boundaryIndex = 0,
    this.openedAtMiddle = false,
    this.profiles = const {},
    this.savedIds = const {},
    this.hasMoreOlder = false,
    this.hasMoreUnread = false,
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.isLoadingUnread = false,
    this.isSending = false,
    this.errorMessage,
  });

  final ChannelFeedStatus status;
  final ChannelEntity? channel;

  /// All loaded messages, oldest→newest (chat-style display).
  ///
  /// `messages[0 .. boundaryIndex - 1]` were already read when the feed opened
  /// (the top section); `messages[boundaryIndex ..]` were unread on open (the
  /// bottom section). The split is the read→unread boundary the list anchors on.
  final List<NoteEntity> messages;

  /// Count of leading read messages — the index where the unread section begins.
  final int boundaryIndex;

  /// True when the channel had unread messages on open, so the list anchors the
  /// boundary at the vertical middle. False → anchored at the bottom (newest).
  final bool openedAtMiddle;

  /// pubkeyHex → ProfileEntity (for author display names / avatars).
  final Map<String, ProfileEntity> profiles;

  /// eventIds the active user has saved/bookmarked.
  final Set<String> savedIds;

  /// More older (read) messages exist above the loaded range.
  final bool hasMoreOlder;

  /// More unread / newer messages may exist below the loaded range.
  final bool hasMoreUnread;

  final bool isLoading;
  final bool isLoadingOlder;
  final bool isLoadingUnread;
  final bool isSending;
  final String? errorMessage;

  ChannelFeedState copyWith({
    ChannelFeedStatus? status,
    ChannelEntity? channel,
    List<NoteEntity>? messages,
    int? boundaryIndex,
    bool? openedAtMiddle,
    Map<String, ProfileEntity>? profiles,
    Set<String>? savedIds,
    bool? hasMoreOlder,
    bool? hasMoreUnread,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isLoadingUnread,
    bool? isSending,
    String? errorMessage,
  }) {
    return ChannelFeedState(
      status: status ?? this.status,
      channel: channel ?? this.channel,
      messages: messages ?? this.messages,
      boundaryIndex: boundaryIndex ?? this.boundaryIndex,
      openedAtMiddle: openedAtMiddle ?? this.openedAtMiddle,
      profiles: profiles ?? this.profiles,
      savedIds: savedIds ?? this.savedIds,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      hasMoreUnread: hasMoreUnread ?? this.hasMoreUnread,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isLoadingUnread: isLoadingUnread ?? this.isLoadingUnread,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
