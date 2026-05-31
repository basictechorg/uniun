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

const _pageSize = 10;

/// Two-band feed bloc:
///   1) Seen rows (newest-first) — pulled until exhausted.
///   2) Unseen rows + new arrivals (newest-first) — paginated next.
/// A single fetched page may straddle the band boundary so users never see a
/// gap. `MarkFeedItemSeenEvent` only writes to DB; it does NOT mutate the
/// in-memory items list so scroll position stays put.
@injectable
class VishnuFeedBloc extends Bloc<VishnuFeedEvent, VishnuFeedState> {
  final GetSeenFeedPageUseCase _getSeenPage;
  final GetUnseenFeedPageUseCase _getUnseenPage;
  final GetUnseenAboveUseCase _getUnseenAbove;
  final WatchUnseenAboveUseCase _watchAbove;
  final MarkFeedItemSeenUseCase _markSeen;
  final GetProfileUseCase _getProfile;
  final GetAllSavedNotesUseCase _getAllSavedNotes;
  final SaveNoteUseCase _saveNote;
  final UnsaveNoteUseCase _unsaveNote;
  final EmbedAndStoreNoteUseCase _embedAndStore;

  StreamSubscription<int>? _newCountSub;
  final Set<String> _markedThisSession = <String>{};

  VishnuFeedBloc(
    this._getSeenPage,
    this._getUnseenPage,
    this._getUnseenAbove,
    this._watchAbove,
    this._markSeen,
    this._getProfile,
    this._getAllSavedNotes,
    this._saveNote,
    this._unsaveNote,
    this._embedAndStore,
  ) : super(const VishnuFeedState()) {
    on<FeedOpenedEvent>(_onOpened, transformer: droppable());
    on<LoadMoreFeedEvent>(_onLoadMore, transformer: droppable());
    on<RefreshFeedEvent>(_onRefresh, transformer: droppable());
    on<MarkFeedItemSeenEvent>(_onMarkSeen, transformer: sequential());
    on<SaveFeedNoteEvent>(_onSave, transformer: sequential());
    on<UnsaveFeedNoteEvent>(_onUnsave, transformer: sequential());
    on<_NewAboveCountChangedEvent>(_onNewAboveCountChanged);
  }

  @override
  Future<void> close() async {
    await _newCountSub?.cancel();
    return super.close();
  }

  // ── First page / refresh ───────────────────────────────────────────────────

  Future<void> _onOpened(
    FeedOpenedEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    if (state.status != VishnuFeedStatus.initial) return;
    emit(state.copyWith(status: VishnuFeedStatus.loading));
    await _resetAndFetchFirstPage(emit);
  }

  Future<void> _onRefresh(
    RefreshFeedEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    emit(state.copyWith(
      status: VishnuFeedStatus.loading,
      newAboveCount: 0,
    ));
    await _resetAndFetchFirstPage(emit);
  }

  Future<void> _resetAndFetchFirstPage(Emitter<VishnuFeedState> emit) async {
    emit(state.copyWith(
      items: const [],
      band: FeedBand.seen,
      clearCursor: true,
      clearTopUnseen: true,
    ));
    await _fetchPage(emit);
    _subscribeUnseenAbove();
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  Future<void> _onLoadMore(
    LoadMoreFeedEvent event,
    Emitter<VishnuFeedState> emit,
  ) async {
    if (!state.hasMore) return;
    if (state.status == VishnuFeedStatus.loadingMore) return;
    if (state.items.isEmpty) return;
    emit(state.copyWith(status: VishnuFeedStatus.loadingMore));
    await _fetchPage(emit);
  }

  /// One page = one screen of items. May straddle the seen → unseen boundary
  /// in a single fetch when the seen band partially fills the page, so users
  /// see no gap.
  ///
  /// In the unseen band, also prepends any items that arrived above the
  /// current top-of-unseen since the last fetch — so LoadMore turns "EFGH"
  /// into "NEFGH" when N arrived during scroll, without disturbing items
  /// already on screen.
  Future<void> _fetchPage(Emitter<VishnuFeedState> emit) async {
    final newItems = <NoteEntity>[];
    var band = state.band;
    DateTime? cursor = state.cursor;
    DateTime? topUnseen = state.topUnseenCursor;

    // Band 1 — SEEN
    if (band == FeedBand.seen) {
      final res = await _getSeenPage.call(
        FeedPageInput(limit: _pageSize, before: cursor),
      );
      final items = res.fold((f) {
        emit(state.copyWith(
          status: VishnuFeedStatus.error,
          errorMessage: f.toMessage(),
        ));
        return <NoteEntity>[];
      }, (l) => l);
      newItems.addAll(items);
      if (items.length < _pageSize) {
        band = FeedBand.unseen;
        cursor = null;
      } else {
        cursor = items.last.created;
      }
    }

    // Band 2 — UNSEEN (fills remaining slots if seen ran out mid-page)
    if (band == FeedBand.unseen && newItems.length < _pageSize) {
      final remaining = _pageSize - newItems.length;

      // 2a) New arrivals above the unseen items already on screen. Only
      //     applies when we've already loaded some unseen rows — first entry
      //     into the band starts fresh.
      if (topUnseen != null) {
        final aboveRes = await _getUnseenAbove.call(
          UnseenAboveInput(topCursor: topUnseen, limit: _pageSize),
        );
        final above = aboveRes.fold((_) => const <NoteEntity>[], (l) => l);
        if (above.isNotEmpty) {
          newItems.addAll(above);
          topUnseen = above.first.created;
        }
      }

      // 2b) Next chunk below the cursor.
      final res = await _getUnseenPage.call(
        FeedPageInput(limit: remaining, before: cursor),
      );
      final items = res.fold((f) {
        emit(state.copyWith(
          status: VishnuFeedStatus.error,
          errorMessage: f.toMessage(),
        ));
        return <NoteEntity>[];
      }, (l) => l);
      newItems.addAll(items);
      if (items.isEmpty) {
        band = FeedBand.exhausted;
      } else {
        cursor = items.last.created;
        // First-ever unseen items loaded → seed topUnseenCursor.
        topUnseen ??= items.first.created;
      }
    }

    final combined = [...state.items, ...newItems];
    final profiles = await _hydrateProfiles(combined);
    final savedIds = await _loadSavedIds();

    emit(state.copyWith(
      items: combined,
      profiles: profiles,
      savedIds: savedIds,
      status: combined.isEmpty
          ? VishnuFeedStatus.empty
          : VishnuFeedStatus.loaded,
      band: band,
      cursor: cursor,
      clearCursor: band == FeedBand.exhausted,
      topUnseenCursor: topUnseen,
    ));

    // Banner cursor moved → re-subscribe so the pill count is correct.
    _subscribeUnseenAbove();
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
    // DB only — don't mutate items so the scroll position holds. Next refresh
    // will resort the row into the seen band.
    await _markSeen.call(event.eventId);
  }

  // ── Pill subscription ──────────────────────────────────────────────────────

  void _subscribeUnseenAbove() {
    _newCountSub?.cancel();
    // Count unseen items that arrived above the topmost unseen row already in
    // memory. Before any unseen has loaded we count everything (epoch 0).
    final cursor = state.topUnseenCursor ??
        DateTime.fromMillisecondsSinceEpoch(0);
    _newCountSub = _watchAbove
        .call(cursor)
        .listen((n) => add(_NewAboveCountChangedEvent(n)));
  }

  void _onNewAboveCountChanged(
    _NewAboveCountChangedEvent event,
    Emitter<VishnuFeedState> emit,
  ) {
    if (event.count == state.newAboveCount) return;
    emit(state.copyWith(newAboveCount: event.count));
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
