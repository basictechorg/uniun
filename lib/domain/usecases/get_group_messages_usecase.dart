import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/group_message_repository.dart';

class GetGroupMessagesInput {
  final String groupId;
  final int limit;
  final DateTime? before;

  const GetGroupMessagesInput({
    required this.groupId,
    this.limit = 50,
    this.before,
  });
}

@lazySingleton
class GetGroupMessagesUseCase extends UseCase<
    Either<Failure, List<NoteEntity>>, GetGroupMessagesInput> {
  final GroupMessageRepository _repository;
  const GetGroupMessagesUseCase(this._repository);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    GetGroupMessagesInput input, {
    bool cached = false,
  }) {
    return _repository.getMessagesForGroup(
      groupId: input.groupId,
      limit: input.limit,
      before: input.before,
    );
  }
}

class GetGroupMessagesAfterInput {
  final String groupId;
  final DateTime after;
  final bool inclusive;
  final int limit;

  const GetGroupMessagesAfterInput({
    required this.groupId,
    required this.after,
    this.inclusive = false,
    this.limit = 10,
  });
}

@lazySingleton
class GetGroupMessagesAfterUseCase extends UseCase<
    Either<Failure, List<NoteEntity>>, GetGroupMessagesAfterInput> {
  final GroupMessageRepository _repository;
  const GetGroupMessagesAfterUseCase(this._repository);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    GetGroupMessagesAfterInput input, {
    bool cached = false,
  }) {
    return _repository.getMessagesForGroupAfter(
      groupId: input.groupId,
      after: input.after,
      inclusive: input.inclusive,
      limit: input.limit,
    );
  }
}

@lazySingleton
class GetGroupMessageByIdUseCase
    extends UseCase<Either<Failure, NoteEntity?>, String> {
  final GroupMessageRepository _repository;
  const GetGroupMessageByIdUseCase(this._repository);

  @override
  Future<Either<Failure, NoteEntity?>> call(String input,
          {bool cached = false}) =>
      _repository.getMessageByEventId(input);
}

@lazySingleton
class GetGroupMessageRepliesUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, String> {
  final GroupMessageRepository _repository;
  const GetGroupMessageRepliesUseCase(this._repository);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(String input,
          {bool cached = false}) =>
      _repository.getGroupMessageReplies(input);
}

@lazySingleton
class GetGroupMessageReplyCountUseCase
    extends UseCase<Either<Failure, int>, String> {
  final GroupMessageRepository _repository;
  const GetGroupMessageReplyCountUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(String input, {bool cached = false}) =>
      _repository.getGroupMessageReplyCount(input);
}
