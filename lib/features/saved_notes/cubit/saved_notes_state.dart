import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';

enum SavedNotesStatus { initial, loading, loaded, error }

class SavedNotesState {
  const SavedNotesState({
    this.status = SavedNotesStatus.initial,
    this.notes = const [],
    this.profiles = const {},
    this.sourceLabels = const {},
    this.errorMessage,
  });

  final SavedNotesStatus status;
  final List<SavedNoteEntity> notes;

  /// pubkeyHex → ProfileEntity for note author display.
  final Map<String, ProfileEntity> profiles;

  /// eventId → pre-rendered chip ("#general" / "🔒 secret"). Only present
  /// for saved items that came from a public or private group; native
  /// Kind-1 saves are absent from the map so the chip stays hidden.
  final Map<String, String> sourceLabels;

  final String? errorMessage;

  SavedNotesState copyWith({
    SavedNotesStatus? status,
    List<SavedNoteEntity>? notes,
    Map<String, ProfileEntity>? profiles,
    Map<String, String>? sourceLabels,
    String? errorMessage,
  }) {
    return SavedNotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      profiles: profiles ?? this.profiles,
      sourceLabels: sourceLabels ?? this.sourceLabels,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
