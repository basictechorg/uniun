import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/shiv/shiv_conversation_entity.dart';
import 'package:uniun/domain/entities/shiv/shiv_message_entity.dart';
import 'package:uniun/domain/repositories/shiv_repository.dart';

@lazySingleton
class GetConversationsUseCase
    extends NoParamsUseCase<Either<Failure, List<ShivConversationEntity>>> {
  final ShivRepository _repository;
  const GetConversationsUseCase(this._repository);

  @override
  Future<Either<Failure, List<ShivConversationEntity>>> call() {
    return _repository.getConversations();
  }
}

/// Lazy stream that fires whenever the conversation collection changes.
/// Consumers (e.g. `ShivAIBloc`) re-call [GetConversationsUseCase] on each
/// emission to refresh the in-memory drawer list — keeps the drawer in sync
/// when Settings → Delete Chat History wipes both Isar tables.
@lazySingleton
class WatchConversationsUseCase {
  final ShivRepository _repository;
  const WatchConversationsUseCase(this._repository);

  Stream<void> call() => _repository.watchConversations();
}

@lazySingleton
class CreateConversationUseCase
    extends UseCase<Either<Failure, ShivConversationEntity>, String> {
  final ShivRepository _repository;
  const CreateConversationUseCase(this._repository);

  @override
  Future<Either<Failure, ShivConversationEntity>> call(String input,
      {bool cached = false}) {
    return _repository.createConversation(input);
  }
}

@lazySingleton
class DeleteConversationUseCase
    extends UseCase<Either<Failure, Unit>, String> {
  final ShivRepository _repository;
  const DeleteConversationUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String input, {bool cached = false}) {
    return _repository.deleteConversation(input);
  }
}

@lazySingleton
class GetMessagesUseCase
    extends UseCase<Either<Failure, List<ShivMessageEntity>>, String> {
  final ShivRepository _repository;
  const GetMessagesUseCase(this._repository);

  @override
  Future<Either<Failure, List<ShivMessageEntity>>> call(String input,
      {bool cached = false}) {
    return _repository.getMessages(input);
  }
}

@lazySingleton
class SaveMessageUseCase
    extends UseCase<Either<Failure, ShivMessageEntity>, ShivMessageEntity> {
  final ShivRepository _repository;
  const SaveMessageUseCase(this._repository);

  @override
  Future<Either<Failure, ShivMessageEntity>> call(ShivMessageEntity input,
      {bool cached = false}) {
    return _repository.saveMessage(input);
  }
}

@lazySingleton
class UpdateMessageContentUseCase
    extends UseCase<Either<Failure, Unit>, (String messageId, String content)> {
  final ShivRepository _repository;
  const UpdateMessageContentUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call((String, String) input,
      {bool cached = false}) {
    return _repository.updateMessageContent(input.$1, input.$2);
  }
}

@lazySingleton
class UpdateConversationTitleUseCase
    extends UseCase<Either<Failure, Unit>,
        (String conversationId, String title)> {
  final ShivRepository _repository;
  const UpdateConversationTitleUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call((String, String) input,
      {bool cached = false}) {
    return _repository.updateConversationTitle(input.$1, input.$2);
  }
}

/// Updates which leaf node the user is currently viewing (for branch switching).
@lazySingleton
class UpdateActiveLeafUseCase
    extends UseCase<Either<Failure, Unit>,
        (String conversationId, String messageId)> {
  final ShivRepository _repository;
  const UpdateActiveLeafUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call((String, String) input,
      {bool cached = false}) {
    return _repository.updateActiveLeaf(input.$1, input.$2);
  }
}
