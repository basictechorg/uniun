import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/feed_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

part 'vishnu_feed_event.dart';
part 'vishnu_feed_state.dart';

const _pageSize = 20;

@injectable
class VishnuFeedBloc extends Bloc<VishnuFeedEvent, VishnuFeedState> {
  final GetOrInitFeedLoadedAtUseCase _getOrInitLoadedAt;
  final SetFeedLoadedAtUseCase _setLoadedAt;
  final GetUnseenQueuePageUseCase _getQueuePage;
  final GetSeenPageUseCase _getSeenPage;
  final WatchNewBufferCountUseCase _watchNewCount;
  final MarkFeedItemSeenUseCase _markSeen;
  final GetProfileUseCase _getProfile;
  final GetAllSavedNotesUseCase _getAllSavedNotes;
  final SaveNoteUseCase _saveNote;
  final UnsaveNoteUseCase _unsaveNote;
  final EmbedAndStoreNoteUseCase _embedAndStore;

  StreamSubscription<int>? _newCountSub;
  final Set<String> _loadedIds = <String>{};
  final Set<String> _markedThisSession = <String>{};

  VishnuFeedBloc(
    this._getOrInitLoadedAt,
    this._setLoadedAt,
    this._getQueuePage,
    this._getSeenPage,
    this._watchNewCount,
    this._markSeen,
    this._getProfile,
    this._getAllSavedNotes,
    this._saveNote,
    this._unsaveNote,
    this._embedAndStore,
  ) : super(const VishnuFeedState()) {
    on<FeedOpenedEvent>(_onOpened, transformer: droppable());
    on<LoadMoreFeedEvent>(_onLoadMore, transformer: droppable());
    on<LoadNewNotesEvent>(_onLoadNew, transformer: droppable());
    on<RefreshFeedEvent>(_onRefresh, transformer: droppable());
    on<MarkFeedItemSeenEvent>(_onMarkSeen, transformer: sequential());
    on<SaveFeedNoteEvent>(_onSave, transformer: sequential());
    on<UnsaveFeedNoteEvent>(_onUnsave, transformer: sequential());
    on<_NewBufferCountChangedEvent>(_onNewCountChanged);
  }

  @override
  Future<void> close() async {
    await _newCountSub?.cancel();
    return super.close();
  }

  // ── Anchor + first page ────────────────────────────────────────────────────

  Future<void> _onOpened(
    FeedOpenedEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    if (state.status != VishnuFeedStatus.initial) return;
    emit(state.copyWith(status: VishnuFeedStatus.loading));
    final loadedAtRes = await _getOrInitLoadedAt.call();
    final loadedAt = loadedAtRes.fold((_) => DateTime.now(), (t) => t);
    emit(state.copyWith(loadedAt: loadedAt));
    _subscribeNewCount(loadedAt);
    await _resetAndFetchFirstPage(emit, loadedAt);
  }

  Future<void> _onLoadNew(
    LoadNewNotesEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    final now = DateTime.now();
    await _setLoadedAt.call(now);
    emit(state.copyWith(loadedAt: now, newCount: 0));
    _subscribeNewCount(now);
    emit(state.copyWith(status: VishnuFeedStatus.loading));
    await _resetAndFetchFirstPage(emit, now);
  }

  Future<void> _onRefresh(
    RefreshFeedEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    // Same semantics as banner tap.
    add(const LoadNewNotesEvent());
  }

  Future<void> _resetAndFetchFirstPage(
    Emitter<VishnuFeedState> emit,
    DateTime loadedAt,
  ) async {
    _loadedIds.clear();
    emit(state.copyWith(
      items: const [],
      bucket: FeedBucket.queue,
      clearCursor: true,
    ));
    await _fetchPage(emit, loadedAt: loadedAt);
  }

  // ── Infinite scroll ────────────────────────────────────────────────────────

  Future<void> _onLoadMore(
    LoadMoreFeedEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    if (state.status == VishnuFeedStatus.loadingMore) return;
    if (state.bucket == FeedBucket.exhausted) return;
    if (state.loadedAt == null) return;
    if (state.items.isEmpty) return;
    emit(state.copyWith(status: VishnuFeedStatus.loadingMore));
    await _fetchPage(emit, loadedAt: state.loadedAt!);
  }

  /// One page = one screen of items. May straddle bucket B → C in a single
  /// fetch when the queue partially fills the page, so users see no gap.
  Future<void> _fetchPage(
    Emitter<VishnuFeedState> emit, {
    required DateTime loadedAt,
  }) async {
    final newItems = <NoteEntity>[];
    var bucket = state.bucket;
    DateTime? cursor = state.cursor;

    // Bucket B (queue)
    if (bucket == FeedBucket.queue) {
      final queueRes = await _getQueuePage.call(
        FeedPageInput(loadedAt: loadedAt, limit: _pageSize, before: cursor),
      );
      final queueItems = queueRes.fold(
        (f) {
          emit(state.copyWith(
            status: VishnuFeedStatus.error,
            errorMessage: f.toMessage(),
          ));
          return <NoteEntity>[];
        },
        (l) => l,
      );
      _appendDedup(newItems, queueItems);
      if (queueItems.length < _pageSize) {
        bucket = FeedBucket.seen;
        cursor = null;
      } else {
        cursor = queueItems.last.created;
      }
    }

    // Bucket C (seen) — fills any remaining slots in this page
    if (bucket == FeedBucket.seen && newItems.length < _pageSize) {
      final remaining = _pageSize - newItems.length;
      final seenRes = await _getSeenPage.call(
        SeenPageInput(limit: remaining, before: cursor),
      );
      final seenItems = seenRes.fold(
        (f) {
          emit(state.copyWith(
            status: VishnuFeedStatus.error,
            errorMessage: f.toMessage(),
          ));
          return <NoteEntity>[];
        },
        (l) => l,
      );
      _appendDedup(newItems, seenItems);
      if (seenItems.isEmpty) {
        bucket = FeedBucket.exhausted;
      } else {
        cursor = seenItems.last.created;
      }
    }

    final combined = [...state.items, ...newItems];
    final profiles = await _hydrateProfiles(combined);
    final savedIds = await _loadSavedIds();

    emit(state.copyWith(
      items: combined,
      profiles: profiles,
      savedIds: savedIds,
      status: VishnuFeedStatus.loaded,
      bucket: bucket,
      cursor: cursor,
      clearCursor: bucket == FeedBucket.exhausted,
    ));
  }

  void _appendDedup(List<NoteEntity> out, List<NoteEntity> incoming) {
    for (final e in incoming) {
      if (_loadedIds.add(e.id)) out.add(e);
    }
  }

  Future<Map<String, ProfileEntity>> _hydrateProfiles(
    List<NoteEntity> items,
  ) async {
    final profiles = Map<String, ProfileEntity>.from(state.profiles);
    final missing = items
        .map((n) => n.authorPubkey)
        .toSet()
        .where((k) => !profiles.containsKey(k));
    for (final pubkey in missing) {
      final r = await _getProfile.call(pubkey);
      r.fold((_) {}, (p) => profiles[pubkey] = p);
    }
    return profiles;
  }

  Future<Set<String>> _loadSavedIds() async {
    final res = await _getAllSavedNotes.call();
    return res.fold(
      (_) => state.savedIds,
      (list) => list.map((e) => e.eventId).toSet(),
    );
  }

  // ── Mark-as-seen ───────────────────────────────────────────────────────────

  Future<void> _onMarkSeen(
    MarkFeedItemSeenEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    if (_markedThisSession.contains(event.eventId)) return;
    _markedThisSession.add(event.eventId);
    // DB write only. We deliberately do not mutate state.items — the user is
    // still reading this load and the position must not shift.
    await _markSeen.call(event.eventId);
  }

  // ── Banner subscription ────────────────────────────────────────────────────

  void _subscribeNewCount(DateTime loadedAt) {
    _newCountSub?.cancel();
    _newCountSub = _watchNewCount
        .call(loadedAt)
        .listen((n) => add(_NewBufferCountChangedEvent(n)));
  }

  void _onNewCountChanged(
    _NewBufferCountChangedEvent event,
    Emitter<VishnuFeedState> emit,
  ) {
    if (event.count == state.newCount) return;
    emit(state.copyWith(newCount: event.count));
  }

  // ── Save / Unsave ──────────────────────────────────────────────────────────

  Future<void> _onSave(
    SaveFeedNoteEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    emit(state.copyWith(savedIds: {...state.savedIds, event.note.id}));
    final result = await _saveNote.call(event.note);
    result.fold(
      (_) {
        final rollback = Set<String>.from(state.savedIds)..remove(event.note.id);
        emit(state.copyWith(savedIds: rollback));
      },
      (savedNote) {
        unawaited(_embedAndStore.call((savedNote.eventId, savedNote.content)));
      },
    );
  }

  Future<void> _onUnsave(
    UnsaveFeedNoteEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    final optimistic = Set<String>.from(state.savedIds)..remove(event.noteId);
    emit(state.copyWith(savedIds: optimistic));
    final result = await _unsaveNote.call(event.noteId);
    result.fold(
      (_) => emit(state.copyWith(savedIds: {...state.savedIds, event.noteId})),
      (_) {},
    );
  }
}
