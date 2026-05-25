part of 'dm_chat_bloc.dart';

@immutable
class DmChatState {
  final bool isLoading;
  final bool isSending;
  final String? otherPubkey;
  final List<DmMessageEntity> messages;
  final String? errorMessage;

  const DmChatState({
    this.isLoading = false,
    this.isSending = false,
    this.otherPubkey,
    this.messages = const [],
    this.errorMessage,
  });

  DmChatState copyWith({
    bool? isLoading,
    bool? isSending,
    String? otherPubkey,
    List<DmMessageEntity>? messages,
    String? errorMessage,
  }) {
    return DmChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      otherPubkey: otherPubkey ?? this.otherPubkey,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
    );
  }
}
