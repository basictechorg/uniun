import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';

enum SavedNotesStatus { initial, loading, loaded, error }

class SavedNotesState {
  const SavedNotesState({
    this.status = SavedNotesStatus.initial,
    this.notes = const [],
    this.profiles = const {},
    this.errorMessage,
  });

  final SavedNotesStatus status;
  final List<SavedNoteEntity> notes;

  /// pubkeyHex → ProfileEntity for note author display.
  final Map<String, ProfileEntity> profiles;

  final String? errorMessage;

  SavedNotesState copyWith({
    SavedNotesStatus? status,
    List<SavedNoteEntity>? notes,
    Map<String, ProfileEntity>? profiles,
    String? errorMessage,
  }) {
    return SavedNotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      profiles: profiles ?? this.profiles,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
