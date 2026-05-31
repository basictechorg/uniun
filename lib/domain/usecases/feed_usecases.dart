import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/feed_repository.dart';

class FeedPageInput {
  final int limit;
  final DateTime? before;
  const FeedPageInput({required this.limit, this.before});
}

@lazySingleton
class GetSeenFeedPageUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, FeedPageInput> {
  final FeedRepository _repo;
  const GetSeenFeedPageUseCase(this._repo);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    FeedPageInput input, {
    bool cached = false,
  }) =>
      _repo.getSeenPage(limit: input.limit, before: input.before);
}

@lazySingleton
class GetUnseenFeedPageUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, FeedPageInput> {
  final FeedRepository _repo;
  const GetUnseenFeedPageUseCase(this._repo);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    FeedPageInput input, {
    bool cached = false,
  }) =>
      _repo.getUnseenPage(limit: input.limit, before: input.before);
}

class UnseenAboveInput {
  final DateTime topCursor;
  final int limit;
  const UnseenAboveInput({required this.topCursor, required this.limit});
}

@lazySingleton
class GetUnseenAboveUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, UnseenAboveInput> {
  final FeedRepository _repo;
  const GetUnseenAboveUseCase(this._repo);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    UnseenAboveInput input, {
    bool cached = false,
  }) =>
      _repo.getUnseenAbove(topCursor: input.topCursor, limit: input.limit);
}

@lazySingleton
class WatchUnseenAboveUseCase {
  final FeedRepository _repo;
  const WatchUnseenAboveUseCase(this._repo);

  Stream<int> call(DateTime topCursor) => _repo.watchUnseenAbove(topCursor);
}

@lazySingleton
class MarkFeedItemSeenUseCase extends UseCase<Either<Failure, Unit>, String> {
  final FeedRepository _repo;
  const MarkFeedItemSeenUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call(String eventId, {bool cached = false}) =>
      _repo.markSeen(eventId);
}
