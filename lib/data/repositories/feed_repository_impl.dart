import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/datasources/feed_read_state_store.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/feed_repository.dart';
import 'package:uniun/domain/repositories/followed_user_repository.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';
import 'package:uniun/domain/repositories/source_label_repository.dart';
import 'package:uniun/domain/repositories/user_repository.dart';

@Injectable(as: FeedRepository)
class FeedRepositoryImpl extends FeedRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  final SourceLabelRepository _sourceLabels;
  final FollowedUserRepository _follows;
  final UserRepository _users;
  final FeedReadStateStore _feedReadState;
  final NoteResolverRepository _resolver;

  FeedRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
    required SourceLabelRepository sourceLabels,
    required FollowedUserRepository follows,
    required UserRepository users,
    required FeedReadStateStore feedReadState,
    required NoteResolverRepository resolver,
  })  : _relations = relations,
        _sourceLabels = sourceLabels,
        _follows = follows,
        _users = users,
        _feedReadState = feedReadState,
        _resolver = resolver;

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
      final existing = _feedReadState.loadedAt;
      if (existing != null) return Right(existing);
      final now = DateTime.now();
      await _feedReadState.setLoadedAt(now);
      return Right(now);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setFeedLoadedAt(DateTime ts) async {
    try {
      await _feedReadState.setLoadedAt(ts);
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Queue / Seen pagination ────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<NoteEntity>>> getUnread({
    required int limit,
    required Set<String> excludeIds,
  }) async {
    try {
      final authors = await _allowedAuthors();
      final rows = await _unreadRows(
        limit: limit,
        excludeIds: excludeIds,
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
      final rows = await _seenRows(
        limit: limit,
        before: before,
        authors: authors,
      );
      return Right(await _toEntities(rows));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// Unread phase — feed-eligible notes that still have an unread row,
  /// `created` desc, skipping anything in [excludeIds] (the already-loaded set).
  /// Served from the `UnreadNote` collection (indexed) then hydrated from the
  /// `Note` collection. Feed-eligible kinds: Kind 1 (gated to [authors]),
  /// Kind 42 public group, Kind 9023 private group — re-filtered live so a
  /// follow/unfollow takes effect immediately. DMs (14/15) never appear.
  ///
  /// NOT bounded by `feedLoadedAt`: newly arrived unread notes are drained too.
  /// No `before` cursor — new arrivals are newer than any cursor would allow.
  /// Over-fetches and loops (advancing an internal `created` cursor) so a run
  /// of already-loaded rows never short-circuits the page.
  Future<List<NoteModel>> _unreadRows({
    required int limit,
    required Set<String> excludeIds,
    required List<String> authors,
  }) async {
    final unreadRows = <UnreadNoteModel>[];
    final addedIds = <String>{};
    DateTime? cursor;

    while (unreadRows.length < limit) {
      var q = isar.unreadNoteModels.filter().group((g) => g
          .group((k1) => k1
              .kindEqualTo(kNoteKind)
              .and()
              .anyOf(authors, (qq, a) => qq.authorPubkeyEqualTo(a)))
          .or()
          .kindEqualTo(kGroupMessageKind)
          .or()
          .kindEqualTo(kPrivateGroupKind));
      if (cursor != null) {
        q = q.and().createdLessThan(cursor, include: true);
      }
      final candidates =
          await q.sortByCreatedDesc().limit(limit * 2).findAll();
      if (candidates.isEmpty) break;

      for (final c in candidates) {
        if (!excludeIds.contains(c.eventId) && addedIds.add(c.eventId)) {
          unreadRows.add(c);
          if (unreadRows.length == limit) break;
        }
      }

      final nextCursor = candidates.last.created;
      final progressed = cursor == null || nextCursor.isBefore(cursor);
      cursor = nextCursor;
      // Source exhausted, or timestamps stopped advancing (degenerate boundary).
      if (candidates.length < limit * 2 || !progressed) break;
    }
    if (unreadRows.isEmpty) return const [];

    final ids = unreadRows.map((r) => r.eventId).toList();
    final notes = await isar.noteModels
        .filter()
        .anyOf(ids, (qq, id) => qq.eventIdEqualTo(id))
        .findAll();
    final byId = {for (final n in notes) n.eventId: n};
    // Preserve the unread rows' created-desc ordering.
    return [
      for (final r in unreadRows)
        if (byId[r.eventId] != null) byId[r.eventId]!,
    ];
  }

  /// Seen bucket — feed-eligible notes that have NO unread row, `created` desc.
  /// Isar can't anti-join across collections, so we page the `Note` collection
  /// and drop candidates present in the (small) feed-eligible unread id set,
  /// over-fetching and looping so a run of unread notes never short-circuits
  /// the bucket into a false "exhausted".
  Future<List<NoteModel>> _seenRows({
    required int limit,
    DateTime? before,
    required List<String> authors,
  }) async {
    final out = <NoteModel>[];
    final addedIds = <String>{};
    Set<String>? unreadIds;
    DateTime? cursor = before;

    while (out.length < limit) {
      var q = isar.noteModels.filter().group((g) => g
          .group((k1) => k1
              .kindEqualTo(kNoteKind)
              .and()
              .anyOf(authors, (qq, a) => qq.authorPubkeyEqualTo(a)))
          .or()
          .kindEqualTo(kGroupMessageKind)
          .or()
          .kindEqualTo(kPrivateGroupKind));
      if (cursor != null) {
        q = q.and().createdLessThan(cursor, include: true);
      }
      final candidates =
          await q.sortByCreatedDesc().limit(limit * 2).findAll();
      if (candidates.isEmpty) break;

      unreadIds ??= await _feedEligibleUnreadIds(authors);
      for (final c in candidates) {
        if (!unreadIds.contains(c.eventId) && addedIds.add(c.eventId)) {
          out.add(c);
          if (out.length == limit) break;
        }
      }

      final nextCursor = candidates.last.created;
      final progressed = cursor == null || nextCursor.isBefore(cursor);
      cursor = nextCursor;
      // Source exhausted, or timestamps stopped advancing (degenerate boundary).
      if (candidates.length < limit * 2 || !progressed) break;
    }
    return out;
  }

  /// All feed-eligible unread event ids (used to exclude unread notes from the
  /// seen bucket). Small set — only currently-unread notes.
  Future<Set<String>> _feedEligibleUnreadIds(List<String> authors) async {
    final ids = await isar.unreadNoteModels
        .filter()
        .group((g) => g
            .group((k1) => k1
                .kindEqualTo(kNoteKind)
                .and()
                .anyOf(authors, (qq, a) => qq.authorPubkeyEqualTo(a)))
            .or()
            .kindEqualTo(kGroupMessageKind)
            .or()
            .kindEqualTo(kPrivateGroupKind))
        .eventIdProperty()
        .findAll();
    return ids.toSet();
  }

  /// Map rows → NoteEntity, attaching live reply/reference counts (edge table)
  /// and group/group source labels (shared [SourceLabelRepository]).
  Future<List<NoteEntity>> _toEntities(List<NoteModel> rows) async {
    if (rows.isEmpty) return const [];
    final labels = await _sourceLabels.resolveMany([
      for (final m in rows)
        if (m.groupId != null || m.privateGroupId != null)
          (eventId: m.eventId, groupId: m.groupId, privateGroupId: m.privateGroupId),
    ]);
    final base = <NoteEntity>[
      for (final m in rows)
        m.toDomain().copyWith(
              cachedReplyCount: await _relations.replyCount(m.eventId),
              referenceCount: await _relations.referenceCount(m.eventId),
              sourceLabel: labels[m.eventId],
            ),
    ];
    return _resolver.enrichWithQuotes(base);
  }

  // ── Banner: live count of new arrivals ─────────────────────────────────────

  @override
  Stream<int> watchNewBufferCount(DateTime loadedAt) {
    final controller = StreamController<int>();

    Future<void> push() async {
      try {
        final authors = await _allowedAuthors();
        final n = await isar.unreadNoteModels
            .filter()
            .group((g) => g
                .group((k1) => k1
                    .kindEqualTo(kNoteKind)
                    .and()
                    .anyOf(authors, (qq, a) => qq.authorPubkeyEqualTo(a)))
                .or()
                .kindEqualTo(kGroupMessageKind)
                .or()
                .kindEqualTo(kPrivateGroupKind))
            .and()
            .createdGreaterThan(loadedAt)
            .count();
        if (!controller.isClosed) controller.add(n);
      } catch (_) {
        if (!controller.isClosed) controller.add(0);
      }
    }

    final notesSub =
        isar.unreadNoteModels.watchLazy().listen((_) => push());
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
        await isar.unreadNoteModels
            .filter()
            .eventIdEqualTo(eventId)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
