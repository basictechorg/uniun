import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';

enum ShivSourcesStatus { loading, loaded }

class ShivSourcesState {
  const ShivSourcesState({
    this.status = ShivSourcesStatus.loading,
    this.notes = const [],
  });

  final ShivSourcesStatus status;
  final List<NoteEntity> notes;
}

/// One-shot loader for Shiv's "Sources" sheet: resolves the RAG source-note ids
/// of the last reply into full [NoteEntity]s for display. Never blocks the UI —
/// any failure degrades to an empty loaded list.
class ShivSourcesCubit extends Cubit<ShivSourcesState> {
  ShivSourcesCubit() : super(const ShivSourcesState());

  Future<void> load(List<String> noteIds) async {
    if (noteIds.isEmpty) {
      emit(const ShivSourcesState(status: ShivSourcesStatus.loaded));
      return;
    }
    final result = await getIt<ResolveNotesByIdsUseCase>().call(noteIds);
    if (isClosed) return;
    final notes = result.fold((_) => <NoteEntity>[], (n) => n);
    emit(ShivSourcesState(status: ShivSourcesStatus.loaded, notes: notes));
  }
}
