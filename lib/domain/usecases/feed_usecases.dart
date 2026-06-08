import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/feed_repository.dart';

// ── Anchor ───────────────────────────────────────────────────────────────────

@lazySingleton
class GetOrInitFeedLoadedAtUseCase
    extends NoParamsUseCase<Either<Failure, DateTime>> {
  final FeedRepository _repo;
  const GetOrInitFeedLoadedAtUseCase(this._repo);

  @override
  Future<Either<Failure, DateTime>> call() => _repo.getOrInitFeedLoadedAt();
}

@lazySingleton
class SetFeedLoadedAtUseCase extends UseCase<Either<Failure, Unit>, DateTime> {
  final FeedRepository _repo;
  const SetFeedLoadedAtUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call(DateTime ts, {bool cached = false}) =>
      _repo.setFeedLoadedAt(ts);
}

// ── Pagination ───────────────────────────────────────────────────────────────

class UnreadPageInput {
  final int limit;
  final Set<String> excludeIds;
  const UnreadPageInput({required this.limit, required this.excludeIds});
}

@lazySingleton
class GetUnreadPageUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, UnreadPageInput> {
  final FeedRepository _repo;
  const GetUnreadPageUseCase(this._repo);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    UnreadPageInput input, {
    bool cached = false,
  }) =>
      _repo.getUnread(limit: input.limit, excludeIds: input.excludeIds);
}

class SeenPageInput {
  final int limit;
  final DateTime? before;
  const SeenPageInput({required this.limit, this.before});
}

@lazySingleton
class GetSeenPageUseCase
    extends UseCase<Either<Failure, List<NoteEntity>>, SeenPageInput> {
  final FeedRepository _repo;
  const GetSeenPageUseCase(this._repo);

  @override
  Future<Either<Failure, List<NoteEntity>>> call(
    SeenPageInput input, {
    bool cached = false,
  }) =>
      _repo.getSeen(limit: input.limit, before: input.before);
}

// ── Banner + mark-seen ───────────────────────────────────────────────────────

@lazySingleton
class WatchNewBufferCountUseCase {
  final FeedRepository _repo;
  const WatchNewBufferCountUseCase(this._repo);

  Stream<int> call(DateTime loadedAt) => _repo.watchNewBufferCount(loadedAt);
}

@lazySingleton
class MarkFeedItemSeenUseCase extends UseCase<Either<Failure, Unit>, String> {
  final FeedRepository _repo;
  const MarkFeedItemSeenUseCase(this._repo);

  @override
  Future<Either<Failure, Unit>> call(String eventId, {bool cached = false}) =>
      _repo.markSeen(eventId);
}
