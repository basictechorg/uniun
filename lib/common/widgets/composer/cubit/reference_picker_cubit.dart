import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/inputs/note_input.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

part 'reference_picker_state.dart';

/// Self-contained data source for the composer reference picker. Queries the
/// unified `Note` collection directly (recent + search), the saved-note table,
/// the user's own notes, and the local drafts — exposing an
/// All / Saved / My notes / Drafts tab filter. Author profiles are enriched
/// lazily so rows render thread-style (avatar + name·time). Selection stays in
/// the page.
@injectable
class ReferencePickerCubit extends Cubit<ReferencePickerState> {
  final GetFeedUseCase _getFeed;
  final SearchNotesUseCase _searchNotes;
  final GetAllSavedNotesUseCase _getAllSaved;
  final GetOwnNotesUseCase _getOwnNotes;
  final GetDraftsUseCase _getDrafts;
  final GetProfileUseCase _getProfile;
  final GetActiveUserKeysUseCase _getKeys;

  List<ComposerReference> _allRecent = const [];
  List<ComposerReference> _saved = const [];
  List<ComposerReference> _own = const [];
  List<ComposerReference> _drafts = const [];

  /// Cumulative profile cache, keyed by pubkey.
  final Map<String, ProfileEntity> _profiles = {};
  String? _selfPubkey;

  ReferencePickerCubit(
    this._getFeed,
    this._searchNotes,
    this._getAllSaved,
    this._getOwnNotes,
    this._getDrafts,
    this._getProfile,
    this._getKeys,
  ) : super(const ReferencePickerState(loading: true)) {
    _init();
  }

  Future<void> _init() async {
    final keysResult = await _getKeys.call();
    _selfPubkey = keysResult.fold((_) => null, (k) => k.pubkeyHex);

    final feedResult = await _getFeed.call(const GetFeedInput(limit: 50));
    _allRecent = feedResult.fold(
      (_) => const <ComposerReference>[],
      (notes) => notes.map(_toRef).toList(),
    );
    // Back the "My notes" tab with a dedicated own-notes query rather than
    // slicing the 50-note feed window — otherwise own notes older than the
    // recent feed slice would be unreferenceable.
    if (_selfPubkey == null) {
      _own = const <ComposerReference>[];
    } else {
      final ownResult = await _getOwnNotes.call(_selfPubkey!);
      _own = ownResult.fold(
        (_) => const <ComposerReference>[],
        (notes) => notes.map(_toRef).toList(),
      );
    }

    final savedResult = await _getAllSaved.call();
    _saved = savedResult.fold(
      (_) => const <ComposerReference>[],
      (list) => list.map((s) => _toRef(s.toNoteEntity())).toList(),
    );

    final draftsResult = await _getDrafts.call();
    _drafts = draftsResult.fold(
      (_) => const <ComposerReference>[],
      (list) => list.map(_draftToRef).toList(),
    );

    if (!isClosed) {
      emit(state.copyWith(results: _allRecent, loading: false));
      _enrichProfiles(_allRecent);
    }
  }

  void setTab(ReferenceTab tab) {
    if (tab == state.tab) return;
    emit(state.copyWith(tab: tab, query: ''));
    _applyQuery('');
  }

  void search(String query) => _applyQuery(query);

  List<ComposerReference> _poolFor(ReferenceTab tab) {
    switch (tab) {
      case ReferenceTab.all:
        return _allRecent;
      case ReferenceTab.saved:
        return _saved;
      case ReferenceTab.own:
        return _own;
      case ReferenceTab.drafts:
        return _drafts;
    }
  }

  Future<void> _applyQuery(String query) async {
    final q = query.trim();
    final tab = state.tab;

    // The All tab searches the unified Note collection; other tabs filter their
    // in-memory pool locally.
    if (tab == ReferenceTab.all && q.isNotEmpty) {
      emit(state.copyWith(query: query, loading: true));
      final result = await _searchNotes.call(q);
      if (isClosed) return;
      final list = result.fold(
        (_) => const <ComposerReference>[],
        (notes) => notes.map(_toRef).toList(),
      );
      emit(state.copyWith(query: query, results: list, loading: false));
      _enrichProfiles(list);
      return;
    }

    final pool = _poolFor(tab);
    final list = q.isEmpty
        ? pool
        : pool
            .where((r) => r.label.toLowerCase().contains(q.toLowerCase()))
            .toList();
    if (!isClosed) {
      emit(state.copyWith(query: query, results: list, loading: false));
      _enrichProfiles(list);
    }
  }

  /// Fetches profiles for any not-yet-cached author pubkeys in [refs] and emits
  /// once with the enriched map. Best-effort: failures are skipped.
  Future<void> _enrichProfiles(List<ComposerReference> refs) async {
    final pubkeys = refs
        .map((r) => r.authorPubkey)
        .whereType<String>()
        .where((p) => p.isNotEmpty && !_profiles.containsKey(p))
        .toSet();
    if (pubkeys.isEmpty) return;
    await Future.wait(pubkeys.map((pk) async {
      final res = await _getProfile.call(pk);
      res.fold((_) {}, (profile) => _profiles[pk] = profile);
    }));
    if (!isClosed) {
      emit(state.copyWith(profiles: Map.of(_profiles)));
    }
  }

  ComposerReference _toRef(NoteEntity n) => ComposerReference(
        id: n.id,
        label: n.content,
        authorPubkey: n.authorPubkey,
        created: n.created,
      );

  ComposerReference _draftToRef(DraftEntity d) => ComposerReference(
        id: d.draftId,
        label: d.content,
        kind: ComposerReferenceKind.draft,
        authorPubkey: _selfPubkey,
        created: d.updatedAt,
      );
}
