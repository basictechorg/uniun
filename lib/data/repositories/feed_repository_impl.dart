import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/channel_message_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/private_channel_message_model.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/feed_repository.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/source_label_repository.dart';

@Injectable(as: FeedRepository)
class FeedRepositoryImpl extends FeedRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  final SourceLabelRepository _sourceLabels;

  FeedRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
    required SourceLabelRepository sourceLabels,
  })  : _relations = relations,
        _sourceLabels = sourceLabels;

  // ── Seen / Unseen pages ────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<NoteEntity>>> getSeenPage({
    required int limit,
    DateTime? before,
  }) =>
      _getPage(seen: true, limit: limit, before: before);

  @override
  Future<Either<Failure, List<NoteEntity>>> getUnseenPage({
    required int limit,
    DateTime? before,
  }) =>
      _getPage(seen: false, limit: limit, before: before);

  @override
  Future<Either<Failure, List<NoteEntity>>> getUnseenAbove({
    required DateTime topCursor,
    required int limit,
  }) async {
    try {
      final notes = await isar.noteModels
          .where(sort: Sort.desc)
          .isSeenEqualToCreatedGreaterThan(false, topCursor)
          .limit(limit)
          .findAll();
      final publicMsgs = await isar.channelMessageModels
          .where(sort: Sort.desc)
          .isSeenEqualToCreatedGreaterThan(false, topCursor)
          .limit(limit)
          .findAll();
      final privateMsgs = await isar.privateChannelMessageModels
          .where(sort: Sort.desc)
          .isSeenEqualToTimestampGreaterThan(false, topCursor)
          .limit(limit)
          .findAll();
      final merged = await _merge(notes, publicMsgs, privateMsgs, limit);
      return Right(merged);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<NoteEntity>>> _getPage({
    required bool seen,
    required int limit,
    DateTime? before,
  }) async {
    try {
      final notes = await _queryNotes(seen, limit, before);
      final publicMsgs = await _queryPublicMsgs(seen, limit, before);
      final privateMsgs = await _queryPrivateMsgs(seen, limit, before);
      final merged = await _merge(notes, publicMsgs, privateMsgs, limit);
      return Right(merged);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // All three queries use composite (isSeen, created/timestamp) indexes via
  // `.where()` — O(log n + limit), no scan.

  Future<List<NoteModel>> _queryNotes(
    bool seen,
    int limit,
    DateTime? before,
  ) async {
    if (before != null) {
      return isar.noteModels
          .where(sort: Sort.desc)
          .isSeenEqualToCreatedLessThan(seen, before)
          .limit(limit)
          .findAll();
    }
    return isar.noteModels
        .where(sort: Sort.desc)
        .isSeenEqualToAnyCreated(seen)
        .limit(limit)
        .findAll();
  }

  Future<List<ChannelMessageModel>> _queryPublicMsgs(
    bool seen,
    int limit,
    DateTime? before,
  ) async {
    if (before != null) {
      return isar.channelMessageModels
          .where(sort: Sort.desc)
          .isSeenEqualToCreatedLessThan(seen, before)
          .limit(limit)
          .findAll();
    }
    return isar.channelMessageModels
        .where(sort: Sort.desc)
        .isSeenEqualToAnyCreated(seen)
        .limit(limit)
        .findAll();
  }

  Future<List<PrivateChannelMessageModel>> _queryPrivateMsgs(
    bool seen,
    int limit,
    DateTime? before,
  ) async {
    if (before != null) {
      return isar.privateChannelMessageModels
          .where(sort: Sort.desc)
          .isSeenEqualToTimestampLessThan(seen, before)
          .limit(limit)
          .findAll();
    }
    return isar.privateChannelMessageModels
        .where(sort: Sort.desc)
        .isSeenEqualToAnyTimestamp(seen)
        .limit(limit)
        .findAll();
  }

  /// Three-way merge by created-desc → truncate to limit → enrich (labels,
  /// relation counts).
  Future<List<NoteEntity>> _merge(
    List<NoteModel> notes,
    List<ChannelMessageModel> msgs,
    List<PrivateChannelMessageModel> privateMsgs,
    int limit,
  ) async {
    final items = <_FeedItem>[
      for (final n in notes) _FeedItem(n.created, _NoteSrc(n)),
      for (final m in msgs) _FeedItem(m.created, _PublicMsgSrc(m)),
      for (final p in privateMsgs) _FeedItem(p.timestamp, _PrivateMsgSrc(p)),
    ]..sort((a, b) => b.created.compareTo(a.created));

    final truncated = items.length > limit ? items.sublist(0, limit) : items;
    if (truncated.isEmpty) return const [];

    final labels = await _sourceLabels.resolveMany([
      for (final i in truncated)
        if (i.source is _PublicMsgSrc)
          (
            eventId: (i.source as _PublicMsgSrc).model.eventId,
            channelId: (i.source as _PublicMsgSrc).model.channelId,
            groupId: null,
          )
        else if (i.source is _PrivateMsgSrc)
          (
            eventId: (i.source as _PrivateMsgSrc).model.eventId,
            channelId: null,
            groupId: (i.source as _PrivateMsgSrc).model.groupId,
          ),
    ]);

    return [
      for (final item in truncated)
        await _toEntityWithCounts(item.source, labels),
    ];
  }

  Future<NoteEntity> _toEntityWithCounts(
    _Source src,
    Map<String, String> labels,
  ) async {
    switch (src) {
      case _NoteSrc(:final model):
        return model.toDomain().copyWith(
              cachedReplyCount: await _relations.replyCount(model.eventId),
              referenceCount: await _relations.referenceCount(model.eventId),
            );
      case _PublicMsgSrc(:final model):
        final base = model.toDomain().copyWith(
              cachedReplyCount: await _relations.replyCount(model.eventId),
              referenceCount: await _relations.referenceCount(model.eventId),
            );
        return base.toNoteEntity().copyWith(
              sourceLabel: labels[model.eventId],
            );
      case _PrivateMsgSrc(:final model):
        return NoteEntity(
          id: model.eventId,
          sig: '',
          authorPubkey: model.senderPubkey,
          content: model.decryptedContent,
          type: NoteType.text,
          eTagRefs: model.eTagRefs,
          pTagRefs: model.pTagRefs,
          tTags: const [],
          created: model.timestamp,
          isSeen: model.isSeen,
          rootEventId: model.rootEventId,
          replyToEventId: model.replyToEventId,
          cachedReplyCount: await _relations.replyCount(model.eventId),
          referenceCount: await _relations.referenceCount(model.eventId),
          sourcePrivateGroupId: model.groupId,
          sourceLabel: labels[model.eventId],
        );
    }
  }

  // ── Banner ─────────────────────────────────────────────────────────────────

  @override
  Stream<int> watchUnseenAbove(DateTime topCursor) {
    final controller = StreamController<int>();

    Future<void> push() async {
      try {
        final n = await isar.noteModels
            .where()
            .isSeenEqualToCreatedGreaterThan(false, topCursor)
            .count();
        final m = await isar.channelMessageModels
            .where()
            .isSeenEqualToCreatedGreaterThan(false, topCursor)
            .count();
        final p = await isar.privateChannelMessageModels
            .where()
            .isSeenEqualToTimestampGreaterThan(false, topCursor)
            .count();
        if (!controller.isClosed) controller.add(n + m + p);
      } catch (_) {
        if (!controller.isClosed) controller.add(0);
      }
    }

    final notesSub = isar.noteModels.watchLazy().listen((_) => push());
    final msgsSub = isar.channelMessageModels.watchLazy().listen((_) => push());
    final privSub =
        isar.privateChannelMessageModels.watchLazy().listen((_) => push());
    push();

    controller.onCancel = () async {
      await notesSub.cancel();
      await msgsSub.cancel();
      await privSub.cancel();
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
          return;
        }
        final msg = await isar.channelMessageModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (msg != null && !msg.isSeen) {
          msg.isSeen = true;
          await isar.channelMessageModels.put(msg);
          return;
        }
        final priv = await isar.privateChannelMessageModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (priv != null && !priv.isSeen) {
          priv.isSeen = true;
          await isar.privateChannelMessageModels.put(priv);
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}

// ── Internal tagged union for merge sort ─────────────────────────────────────

sealed class _Source {
  const _Source();
}

class _NoteSrc extends _Source {
  final NoteModel model;
  const _NoteSrc(this.model);
}

class _PublicMsgSrc extends _Source {
  final ChannelMessageModel model;
  const _PublicMsgSrc(this.model);
}

class _PrivateMsgSrc extends _Source {
  final PrivateChannelMessageModel model;
  const _PrivateMsgSrc(this.model);
}

class _FeedItem {
  final DateTime created;
  final _Source source;
  const _FeedItem(this.created, this.source);
}
