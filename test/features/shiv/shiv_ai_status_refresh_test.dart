import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';

/// Regression guard for the "Shiv chat bubble loading indicator never shows"
/// bug. The conversations watcher (`shivConversationModels.watchLazy`) re-fires
/// `loadConversations` on EVERY conversation mutation — including the
/// conversation-create + auto-title update that happen WHILE the first reply is
/// streaming. If that refresh downgrades the in-flight `streaming` status to
/// `idle`, the chat page swaps the live `_StreamingBubble` for a regular
/// (empty) one, hiding both the typing dots and the streamed tokens until the
/// turn completes. The refresh must therefore preserve a streaming turn.
void main() {
  group('ShivAIBloc.refreshStatus', () {
    test('preserves an in-flight streaming turn so the bubble keeps streaming',
        () {
      expect(
        ShivAIBloc.refreshStatus(ShivChatStatus.streaming, activeGone: false),
        ShivChatStatus.streaming,
      );
    });

    test('drops to idle when the active conversation was deleted mid-stream',
        () {
      // Settings → Delete Chat History can wipe the open conversation while it
      // streams; there is nothing left to stream into, so settle to idle.
      expect(
        ShivAIBloc.refreshStatus(ShivChatStatus.streaming, activeGone: true),
        ShivChatStatus.idle,
      );
    });

    test('non-streaming statuses settle to idle on a list refresh', () {
      expect(
        ShivAIBloc.refreshStatus(ShivChatStatus.chatIdle, activeGone: false),
        ShivChatStatus.idle,
      );
      expect(
        ShivAIBloc.refreshStatus(ShivChatStatus.error, activeGone: false),
        ShivChatStatus.idle,
      );
      expect(
        ShivAIBloc.refreshStatus(ShivChatStatus.idle, activeGone: false),
        ShivChatStatus.idle,
      );
    });
  });
}
