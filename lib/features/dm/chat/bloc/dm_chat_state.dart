part of 'dm_chat_bloc.dart';

@immutable
class DmChatState {
  final bool isLoading;
  final bool isSending;
  final String? otherPubkey;
  final List<NoteEntity> messages;

  /// pubkeyHex → ProfileEntity (for author display names / avatars).
  final Map<String, ProfileEntity> profiles;
  final String? errorMessage;

  /// The message being replied to (embedded by value into the next send), or
  /// null when not replying. Drives the composer reply strip.
  final NoteEntity? replyingToNote;

  const DmChatState({
    this.isLoading = false,
    this.isSending = false,
    this.otherPubkey,
    this.messages = const [],
    this.profiles = const {},
    this.errorMessage,
    this.replyingToNote,
  });

  DmChatState copyWith({
    bool? isLoading,
    bool? isSending,
    String? otherPubkey,
    List<NoteEntity>? messages,
    Map<String, ProfileEntity>? profiles,
    String? errorMessage,
    NoteEntity? replyingToNote,
    bool clearReplyingTo = false,
  }) {
    return DmChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      otherPubkey: otherPubkey ?? this.otherPubkey,
      messages: messages ?? this.messages,
      profiles: profiles ?? this.profiles,
      errorMessage: errorMessage,
      replyingToNote:
          clearReplyingTo ? null : (replyingToNote ?? this.replyingToNote),
    );
  }
}
