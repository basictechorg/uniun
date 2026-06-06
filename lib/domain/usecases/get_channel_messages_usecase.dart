import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/channel_message_repository.dart';

class GetChannelMessagesInput {
  final String channelId;
  final int limit;
  final DateTime? before;

  const GetChannelMessagesInput({
    required this.channelId,
    this.limit = 50,
    this.before,
  });
}

@lazySingleton
class GetChannelMessagesUseCase extends UseCase<
    Either<Failure, List<NoteEntity>>, GetChannelMessagesInput> {
  final ChannelMessageRepository _repository;
  const GetChannelMessagesUseCase(this._repository);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    GetChannelMessagesInput input, {
    bool cached = false,
  }) {
    return _repository.getMessagesForChannel(
      channelId: input.channelId,
      limit: input.limit,
      before: input.before,
    );
  }
}

@lazySingleton
class GetChannelMessageByIdUseCase
    extends UseCase<Either<Failure, NoteEntity?>, String> {
  final ChannelMessageRepository _repository;
  const GetChannelMessageByIdUseCase(this._repository);

  @override
  Future<Either<Failure, NoteEntity?>> call(String input,
          {bool cached = false}) =>
      _repository.getMessageByEventId(input);
}

@lazySingleton
class GetChannelMessageRepliesUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, String> {
  final ChannelMessageRepository _repository;
  const GetChannelMessageRepliesUseCase(this._repository);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(String input,
          {bool cached = false}) =>
      _repository.getChannelMessageReplies(input);
}

@lazySingleton
class GetChannelMessageReplyCountUseCase
    extends UseCase<Either<Failure, int>, String> {
  final ChannelMessageRepository _repository;
  const GetChannelMessageReplyCountUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(String input, {bool cached = false}) =>
      _repository.getChannelMessageReplyCount(input);
}
