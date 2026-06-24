import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/shiv/shiv_conversation_entity.dart';
import 'package:uniun/domain/entities/shiv/shiv_message_entity.dart';

abstract class ShivRepository {
  Future<Either<Failure, List<ShivConversationEntity>>> getConversations();
  Future<Either<Failure, ShivConversationEntity>> createConversation(String title);
  Future<Either<Failure, Unit>> updateConversationTitle(String conversationId, String title);
  /// Updates the active leaf node for branch switching.
  Future<Either<Failure, Unit>> updateActiveLeaf(String conversationId, String messageId);
  Future<Either<Failure, Unit>> deleteConversation(String conversationId);
  Future<Either<Failure, List<ShivMessageEntity>>> getMessages(String conversationId);
  Future<Either<Failure, ShivMessageEntity>> saveMessage(ShivMessageEntity message);
  Future<Either<Failure, Unit>> updateMessageContent(String messageId, String content);

  /// Fires every time the conversation collection changes (added / deleted /
  /// bulk-cleared). The stream emits void — consumers should re-call
  /// [getConversations] to fetch the fresh list. Used by the chat bloc to keep
  /// the drawer list in sync when the user wipes chat history from Settings.
  Stream<void> watchConversations();
}
