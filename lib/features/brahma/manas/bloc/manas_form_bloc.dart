import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uuid/uuid.dart';

part 'manas_form_event.dart';
part 'manas_form_state.dart';

const int _maxPreviewChars = 80;

/// Manas membership is **saved-only**. Drafts and own-but-unsaved notes are
/// not eligible — the form's search pool is exactly the user's saved-notes
/// table, loaded once on open and filtered in-memory on each keystroke.
@injectable
class ManasFormBloc extends Bloc<ManasFormEvent, ManasFormState> {
  final UpsertManasUseCase _upsert;
  final GetManasByIdUseCase _getById;
  final DeleteManasUseCase _delete;
  final AddNoteToManasUseCase _addLink;
  final RemoveNoteFromManasUseCase _removeLink;
  final GetNoteIdsForManasUseCase _getLinks;
  final GetAllSavedNotesUseCase _getAllSaved;

  // Cached saved-notes pool for search + preview resolution. Loaded once on
  // form open; re-loaded only if the user adds notes outside the form
  // lifetime — we accept that tradeoff for the typing-fast UX.
  List<SavedNoteEntity> _savedPool = const [];

  ManasFormBloc(
    this._upsert,
    this._getById,
    this._delete,
    this._addLink,
    this._removeLink,
    this._getLinks,
    this._getAllSaved,
  ) : super(const ManasFormState()) {
    on<ManasFormLoadEvent>(_onLoad);
    on<ManasFormNameChangedEvent>(_onName);
    on<ManasFormDescriptionChangedEvent>(_onDescription);
    on<ManasFormIconPickedEvent>(_onIconPicked);
    on<ManasFormColorsPickedEvent>(_onColorsPicked);
    on<ManasFormSearchEvent>(_onSearch, transformer: restartable());
    on<ManasFormToggleMembershipEvent>(_onToggle);
    on<ManasFormSubmitEvent>(_onSubmit, transformer: droppable());
    on<ManasFormDeleteEvent>(_onDelete, transformer: droppable());
  }

  Future<void> _onLoad(
      ManasFormLoadEvent event, Emitter<ManasFormState> emit) async {
    emit(state.copyWith(status: ManasFormStatus.loading));

    // Saved-notes pool — same data for create and edit modes.
    final savedRes = await _getAllSaved.call();
    _savedPool = savedRes
        .fold<List<SavedNoteEntity>>((_) => const [], (l) => l);

    if (event.manasId == null) {
      emit(state.copyWith(
        status: ManasFormStatus.ready,
        manasId: const Uuid().v4(),
        isEditMode: false,
        createdAt: DateTime.now(),
      ));
      return;
    }

    emit(state.copyWith(isEditMode: true));
    final manasRes = await _getById.call(event.manasId!);
    final manas = manasRes.fold<ManasEntity?>((_) => null, (m) => m);
    if (manas == null) {
      emit(state.copyWith(
        status: ManasFormStatus.error,
        errorMessage: 'Manas not found',
      ));
      return;
    }

    final linksRes = await _getLinks.call(event.manasId!);
    final noteIds = linksRes.fold<List<String>>((_) => const [], (l) => l);

    final previews = {
      for (final id in noteIds) id: _previewFromPool(id),
    };

    emit(state.copyWith(
      status: ManasFormStatus.ready,
      manasId: manas.manasId,
      name: manas.name,
      description: manas.description ?? '',
      iconName: manas.iconName,
      // Existing Manas with a stored icon → treat it as pinned so name
      // edits don't silently overwrite the user's prior choice.
      iconUserPicked: manas.iconName != null,
      colorHexes: manas.colorHexes,
      persistedMembership: noteIds.toSet(),
      pendingMembership: noteIds.toSet(),
      membershipPreviews: previews,
      createdAt: manas.createdAt,
    ));
  }

  void _onName(
      ManasFormNameChangedEvent event, Emitter<ManasFormState> emit) {
    // Re-run icon auto-suggest as long as the user hasn't pinned a choice.
    // Clearing the name with no keyword match collapses back to fallback
    // via clearIcon=true so the tile re-renders the default.
    if (state.iconUserPicked) {
      emit(state.copyWith(name: event.value, clearError: true));
      return;
    }
    final suggested = ManasIcons.suggestFromName(event.value);
    emit(state.copyWith(
      name: event.value,
      clearError: true,
      iconName: suggested,
      clearIcon: suggested == null,
    ));
  }

  void _onDescription(
      ManasFormDescriptionChangedEvent event, Emitter<ManasFormState> emit) {
    emit(state.copyWith(description: event.value));
  }

  void _onIconPicked(
      ManasFormIconPickedEvent event, Emitter<ManasFormState> emit) {
    emit(state.copyWith(
      iconName: event.iconName,
      iconUserPicked: true,
    ));
  }

  void _onColorsPicked(
      ManasFormColorsPickedEvent event, Emitter<ManasFormState> emit) {
    emit(state.copyWith(colorHexes: event.colorHexes));
  }

  Future<void> _onSearch(
      ManasFormSearchEvent event, Emitter<ManasFormState> emit) async {
    final q = event.query.trim();
    if (q.isEmpty) {
      emit(state.copyWith(
        searchQuery: '',
        searchResults: const [],
        searching: false,
      ));
      return;
    }

    emit(state.copyWith(searchQuery: q, searching: true));

    final lower = q.toLowerCase();
    final results = <ManasNotePreview>[];
    for (final s in _savedPool) {
      if (!s.content.toLowerCase().contains(lower)) continue;
      results.add(ManasNotePreview(
        noteId: s.eventId,
        preview: _shortenPreview(s.content),
        kind: ManasNoteKind.saved,
      ));
      if (results.length >= 30) break;
    }

    if (isClosed) return;
    emit(state.copyWith(searchResults: results, searching: false));
  }

  void _onToggle(ManasFormToggleMembershipEvent event,
      Emitter<ManasFormState> emit) {
    final next = {...state.pendingMembership};
    final previews = {...state.membershipPreviews};
    if (next.contains(event.preview.noteId)) {
      next.remove(event.preview.noteId);
    } else {
      next.add(event.preview.noteId);
      previews[event.preview.noteId] = event.preview;
    }
    emit(state.copyWith(
      pendingMembership: next,
      membershipPreviews: previews,
    ));
  }

  Future<void> _onSubmit(
      ManasFormSubmitEvent event, Emitter<ManasFormState> emit) async {
    if (!state.canSave) return;
    emit(state.copyWith(status: ManasFormStatus.saving, clearError: true));

    final manasId = state.manasId ?? const Uuid().v4();
    final now = DateTime.now();
    final entity = ManasEntity(
      manasId: manasId,
      name: state.name.trim(),
      description: state.description.trim().isEmpty
          ? null
          : state.description.trim(),
      iconName: state.iconName,
      colorHexes: state.colorHexes,
      createdAt: state.createdAt ?? now,
      updatedAt: now,
    );

    final upsertRes = await _upsert.call(entity);
    final failure = upsertRes.fold((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(
        status: ManasFormStatus.error,
        errorMessage: failure.toMessage(),
      ));
      return;
    }

    final added = state.pendingMembership.difference(state.persistedMembership);
    final removed = state.persistedMembership.difference(state.pendingMembership);

    for (final id in removed) {
      await _removeLink.call(ManasNoteLink(manasId, id));
    }
    for (final id in added) {
      await _addLink.call(ManasNoteLink(manasId, id));
    }

    emit(state.copyWith(
      status: ManasFormStatus.saved,
      manasId: manasId,
      persistedMembership: {...state.pendingMembership},
    ));
  }

  Future<void> _onDelete(
      ManasFormDeleteEvent event, Emitter<ManasFormState> emit) async {
    final id = state.manasId;
    if (id == null) return;
    emit(state.copyWith(status: ManasFormStatus.saving));
    final r = await _delete.call(id);
    r.fold(
      (f) => emit(state.copyWith(
          status: ManasFormStatus.error, errorMessage: f.toMessage())),
      (_) => emit(state.copyWith(status: ManasFormStatus.deleted)),
    );
  }

  ManasNotePreview _previewFromPool(String noteId) {
    for (final s in _savedPool) {
      if (s.eventId == noteId) {
        return ManasNotePreview(
          noteId: noteId,
          preview: _shortenPreview(s.content),
          kind: ManasNoteKind.saved,
        );
      }
    }
    return ManasNotePreview(
      noteId: noteId,
      preview: '',
      kind: ManasNoteKind.unknown,
    );
  }

  String _shortenPreview(String body) {
    final clean = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= _maxPreviewChars) return clean;
    return '${clean.substring(0, _maxPreviewChars)}…';
  }
}
