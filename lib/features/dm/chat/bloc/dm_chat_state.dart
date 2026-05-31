part of 'dm_chat_bloc.dart';

@immutable
class DmChatState {
  final bool isLoading;
  final bool isSending;
  final String? otherPubkey;
  final List<DmMessageEntity> messages;

  /// pubkeyHex → ProfileEntity (for author display names / avatars).
  final Map<String, ProfileEntity> profiles;
  final String? errorMessage;

  const DmChatState({
    this.isLoading = false,
    this.isSending = false,
    this.otherPubkey,
    this.messages = const [],
    this.profiles = const {},
    this.errorMessage,
  });

  DmChatState copyWith({
    bool? isLoading,
    bool? isSending,
    String? otherPubkey,
    List<DmMessageEntity>? messages,
    Map<String, ProfileEntity>? profiles,
    String? errorMessage,
  }) {
    return DmChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      otherPubkey: otherPubkey ?? this.otherPubkey,
      messages: messages ?? this.messages,
      profiles: profiles ?? this.profiles,
      errorMessage: errorMessage,
    );
  }
}
