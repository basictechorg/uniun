import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'saved_notes_state.dart';

class SavedNotesCubit extends Cubit<SavedNotesState> {
  SavedNotesCubit() : super(const SavedNotesState());

  Future<void> load() async {
    emit(state.copyWith(status: SavedNotesStatus.loading));
    final result = await getIt<GetAllSavedNotesUseCase>().call();
    await result.fold(
      (f) async => emit(state.copyWith(
        status: SavedNotesStatus.error,
        errorMessage: f.toMessage(),
      )),
      (notes) async {
        final profiles = await _loadProfiles(notes);
        if (isClosed) return;
        emit(state.copyWith(
          status: SavedNotesStatus.loaded,
          notes: notes,
          profiles: profiles,
        ));
      },
    );
  }

  Future<Map<String, ProfileEntity>> _loadProfiles(
      List<SavedNoteEntity> notes) async {
    final pubkeys = notes.map((n) => n.authorPubkey).toSet();
    final profiles = <String, ProfileEntity>{};
    for (final pk in pubkeys) {
      final result = await getIt<GetProfileUseCase>().call(pk);
      result.fold((_) => null, (p) => profiles[pk] = p);
    }
    return profiles;
  }
}
