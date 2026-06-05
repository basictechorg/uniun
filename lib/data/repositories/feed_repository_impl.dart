import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/feed_read_state_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/feed_repository.dart';
import 'package:uniun/domain/repositories/followed_user_repository.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/source_label_repository.dart';
import 'package:uniun/domain/repositories/user_repository.dart';

@Injectable(as: FeedRepository)
class FeedRepositoryImpl extends FeedRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  final SourceLabelRepository _sourceLabels;
  final FollowedUserRepository _follows;
  final UserRepository _users;

  FeedRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
    required SourceLabelRepository sourceLabels,
    required FollowedUserRepository follows,
    required UserRepository users,
  })  : _relations = relations,
        _sourceLabels = sourceLabels,
        _follows = follows,
        _users = users;

  /// Author allow-list for Kind 1 feed notes: own pubkey + everyone followed.
  /// Empty result = effectively-impossible filter (no Kind 1 notes shown) — but
  /// in practice we always have at least the own pubkey here once a user is
  /// signed in, so the empty-state UI handles the no-content case upstream.
  Future<List<String>> _allowedAuthors() async {
    final user = await _users.getActiveUser();
    final own = user.fold((_) => null, (u) => u.pubkeyHex);
    final followed = await _follows.getAllPubkeys();
    final list = followed.fold((_) => const <String>[], (l) => l);
    return [if (own != null) own, ...list];
  }

  // ── Anchor (feedLoadedAt) ──────────────────────────────────────────────────

  @override
  Future<Either<Failure, DateTime>> getOrInitFeedLoadedAt() async {
    try {
      final row = await isar.feedReadStateModels.get(0);
      if (row != null) return Right(row.feedLoadedAt);
      final now = DateTime.now();
      await isar.writeTxn(() async {
        await isar.feedReadStateModels.put(
          FeedReadStateModel()..feedLoadedAt = now,
        );
      });
      return Right(now);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setFeedLoadedAt(DateTime ts) async {
    try {
      await isar.writeTxn(() async {
        await isar.feedReadStateModels.put(
          FeedReadStateModel()..feedLoadedAt = ts,
        );
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Queue / Seen pagination ────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<NoteEntity>>> getUnseenQueue({
    required DateTime loadedAt,
    required int limit,
    DateTime? before,
  }) async {
    try {
      final authors = await _allowedAuthors();
      final rows = await _queryFeed(
        seen: false,
        loadedAt: loadedAt,
        limit: limit,
        before: before,
        authors: authors,
      );
      return Right(await _toEntities(rows));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> getSeen({
    required int limit,
    DateTime? before,
  }) async {
    try {
      final authors = await _allowedAuthors();
      final rows = await _queryFeed(
        seen: true,
        loadedAt: null,
        limit: limit,
        before: before,
        authors: authors,
      );
      return Right(await _toEntities(rows));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// Single-collection feed query. Feed-eligible kinds only: Kind 1 (gated to
  /// [authors]), Kind 42 public channel, Kind 9023 private channel. DMs
  /// (Kind 14/15) are excluded — they never appear in the Vishnu feed.
  Future<List<NoteModel>> _queryFeed({
    required bool seen,
    DateTime? loadedAt,
    required int limit,
    DateTime? before,
    required List<String> authors,
  }) {
    var q = isar.noteModels
        .filter()
        .isSeenEqualTo(seen)
        .and()
        .group((g) => g
            .group((k1) => k1
                .kindEqualTo(kNoteKind)
                .and()
                .anyOf(authors, (qq, a) => qq.authorPubkeyEqualTo(a)))
            .or()
            .kindEqualTo(kChannelMessageKind)
            .or()
            .kindEqualTo(kPrivateChannelKind));
    if (loadedAt != null) {
      q = q.and().createdLessThan(loadedAt, include: true);
    }
    if (before != null) {
      q = q.and().createdLessThan(before, include: true);
    }
    return q.sortByCreatedDesc().limit(limit).findAll();
  }

  /// Map rows → NoteEntity, attaching live reply/reference counts (edge table)
  /// and channel/group source labels (shared [SourceLabelRepository]).
  Future<List<NoteEntity>> _toEntities(List<NoteModel> rows) async {
    if (rows.isEmpty) return const [];
    final labels = await _sourceLabels.resolveMany([
      for (final m in rows)
        if (m.channelId != null || m.groupId != null)
          (eventId: m.eventId, channelId: m.channelId, groupId: m.groupId),
    ]);
    return [
      for (final m in rows)
        m.toDomain().copyWith(
              cachedReplyCount: await _relations.replyCount(m.eventId),
              referenceCount: await _relations.referenceCount(m.eventId),
              sourceLabel: labels[m.eventId],
            ),
    ];
  }

  // ── Banner: live count of new arrivals ─────────────────────────────────────

  @override
  Stream<int> watchNewBufferCount(DateTime loadedAt) {
    final controller = StreamController<int>();

    Future<void> push() async {
      try {
        final authors = await _allowedAuthors();
        final n = await isar.noteModels
            .filter()
            .isSeenEqualTo(false)
            .and()
            .group((g) => g
                .group((k1) => k1
                    .kindEqualTo(kNoteKind)
                    .and()
                    .anyOf(authors, (qq, a) => qq.authorPubkeyEqualTo(a)))
                .or()
                .kindEqualTo(kChannelMessageKind)
                .or()
                .kindEqualTo(kPrivateChannelKind))
            .and()
            .createdGreaterThan(loadedAt)
            .count();
        if (!controller.isClosed) controller.add(n);
      } catch (_) {
        if (!controller.isClosed) controller.add(0);
      }
    }

    final notesSub = isar.noteModels.watchLazy().listen((_) => push());
    push();

    controller.onCancel = () async {
      await notesSub.cancel();
    };

    return controller.stream;
  }

  // ── Mark seen ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> markSeen(String eventId) async {
    try {
      await isar.writeTxn(() async {
        final note = await isar.noteModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (note != null && !note.isSeen) {
          note.isSeen = true;
          await isar.noteModels.put(note);
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
