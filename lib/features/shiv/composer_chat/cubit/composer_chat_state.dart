import 'package:freezed_annotation/freezed_annotation.dart';

part 'composer_chat_state.freezed.dart';

enum ComposerChatStatus { idle, streaming, error, noModel }

/// One question/answer exchange in the composer-chat.
@freezed
abstract class ComposerTurn with _$ComposerTurn {
  const factory ComposerTurn({
    required String question,
    @Default('') String answer,
  }) = _ComposerTurn;
}

@freezed
abstract class ComposerChatState with _$ComposerChatState {
  const factory ComposerChatState({
    /// True while the composer is in chat mode (a Manas was picked).
    @Default(false) bool active,

    /// Display name of the picked Manas (null = whole library).
    String? manasName,

    /// Completed (and the in-flight) Q&A turns, oldest first.
    @Default(<ComposerTurn>[]) List<ComposerTurn> turns,

    /// In-flight answer text for the current turn (null when not streaming).
    String? streaming,
    @Default(ComposerChatStatus.idle) ComposerChatStatus status,
    String? errorMessage,
  }) = _ComposerChatState;
}
