import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/inputs/note_input.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';

part 'reference_picker_state.dart';

/// Self-contained data source for the composer reference picker. Queries the
/// unified `Note` collection directly (recent + search) and the saved-note
/// table, exposing an All / Saved tab filter. Selection stays in the page.
@injectable
class ReferencePickerCubit extends Cubit<ReferencePickerState> {
  final GetFeedUseCase _getFeed;
  final SearchNotesUseCase _searchNotes;
  final GetAllSavedNotesUseCase _getAllSaved;

  List<ComposerReference> _allRecent = const [];
  List<ComposerReference> _saved = const [];

  ReferencePickerCubit(
    this._getFeed,
    this._searchNotes,
    this._getAllSaved,
  ) : super(const ReferencePickerState(loading: true)) {
    _init();
  }

  Future<void> _init() async {
    final feedResult = await _getFeed.call(const GetFeedInput(limit: 50));
    _allRecent = feedResult.fold(
      (_) => const <ComposerReference>[],
      (notes) => notes.map(_toRef).toList(),
    );
    final savedResult = await _getAllSaved.call();
    _saved = savedResult.fold(
      (_) => const <ComposerReference>[],
      (list) => list.map((s) => _toRef(s.toNoteEntity())).toList(),
    );
    if (!isClosed) {
      emit(state.copyWith(results: _allRecent, loading: false));
    }
  }

  void setTab(ReferenceTab tab) {
    if (tab == state.tab) return;
    emit(state.copyWith(tab: tab, query: ''));
    _applyQuery('');
  }

  void search(String query) => _applyQuery(query);

  Future<void> _applyQuery(String query) async {
    final q = query.trim();
    if (state.tab == ReferenceTab.saved) {
      final filtered = q.isEmpty
          ? _saved
          : _saved
              .where((r) => r.label.toLowerCase().contains(q.toLowerCase()))
              .toList();
      if (!isClosed) {
        emit(state.copyWith(query: query, results: filtered, loading: false));
      }
      return;
    }

    // All tab.
    if (q.isEmpty) {
      if (!isClosed) {
        emit(state.copyWith(query: query, results: _allRecent, loading: false));
      }
      return;
    }
    emit(state.copyWith(query: query, loading: true));
    final result = await _searchNotes.call(q);
    if (isClosed) return;
    final list = result.fold(
      (_) => const <ComposerReference>[],
      (notes) => notes.map(_toRef).toList(),
    );
    emit(state.copyWith(query: query, results: list, loading: false));
  }

  ComposerReference _toRef(NoteEntity n) =>
      ComposerReference(id: n.id, label: n.content);
}
