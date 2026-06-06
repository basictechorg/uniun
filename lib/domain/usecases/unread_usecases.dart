import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/repositories/unread_repository.dart';

// ── Mark-seen use cases ───────────────────────────────────────────────────────

@lazySingleton
class MarkUnreadSeenUseCase extends UseCase<Either<Failure, Unit>, String> {
  final UnreadRepository _repository;
  const MarkUnreadSeenUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String eventId, {bool cached = false}) =>
      _repository.markSeen(eventId);
}

@lazySingleton
class MarkChannelSeenUseCase extends UseCase<Either<Failure, Unit>, String> {
  final UnreadRepository _repository;
  const MarkChannelSeenUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String channelId, {bool cached = false}) =>
      _repository.markChannelSeen(channelId);
}

@lazySingleton
class MarkPrivateChannelSeenUseCase
    extends UseCase<Either<Failure, Unit>, String> {
  final UnreadRepository _repository;
  const MarkPrivateChannelSeenUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String groupId, {bool cached = false}) =>
      _repository.markPrivateChannelSeen(groupId);
}

@lazySingleton
class MarkConversationSeenUseCase extends UseCase<Either<Failure, Unit>, int> {
  final UnreadRepository _repository;
  const MarkConversationSeenUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(int conversationId,
          {bool cached = false}) =>
      _repository.markConversationSeen(conversationId);
}
