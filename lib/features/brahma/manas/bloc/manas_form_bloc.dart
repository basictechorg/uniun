import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uuid/uuid.dart';

part 'manas_form_event.dart';
part 'manas_form_state.dart';

const int _maxPreviewChars = 80;

/// A single searchable note in the form's in-memory pool. Backed by either an
/// own (authored) note or a saved note — deduped by [noteId] in [_onLoad].
class _PoolNote {
  const _PoolNote(this.noteId, this.content, this.kind);
  final String noteId;
  final String content;
  final ManasNoteKind kind;
}

/// The form's "Add notes" search pool is every Brahma note: **every note the
/// user authored** (own pubkey, any kind), the user's local **drafts**, and
/// the user's **saved-notes** table — deduped by id, loaded once on open and
/// filtered in-memory on each keystroke. Saved wins the display kind when a
/// note is both authored and saved (draft ids never collide with event ids).
@injectable
class ManasFormBloc extends Bloc<ManasFormEvent, ManasFormState> {
  final UpsertManasUseCase _upsert;
  final GetManasByIdUseCase _getById;
  final DeleteManasUseCase _delete;
  final AddNoteToManasUseCase _addLink;
  final RemoveNoteFromManasUseCase _removeLink;
  final GetNoteIdsForManasUseCase _getLinks;
  final GetAllSavedNotesUseCase _getAllSaved;
  final GetOwnNotesUseCase _getOwnNotes;
  final GetActiveUserUseCase _getActiveUser;
  final GetDraftsUseCase _getDrafts;

  // Cached search + preview pool: own (authored) notes ∪ saved notes, deduped
  // by id. Loaded once on form open; re-loaded only if the user adds notes
  // outside the form lifetime — we accept that tradeoff for the typing-fast UX.
  List<_PoolNote> _pool = const [];

  ManasFormBloc(
    this._upsert,
    this._getById,
    this._delete,
    this._addLink,
    this._removeLink,
    this._getLinks,
    this._getAllSaved,
    this._getOwnNotes,
    this._getActiveUser,
    this._getDrafts,
  ) : super(const ManasFormState()) {
    on<ManasFormLoadEvent>(_onLoad);
    on<ManasFormNameChangedEvent>(_onName);
    on<ManasFormDescriptionChangedEvent>(_onDescription);
    on<ManasFormIconPickedEvent>(_onIconPicked);
    on<ManasFormSearchEvent>(_onSearch, transformer: restartable());
    on<ManasFormToggleMembershipEvent>(_onToggle);
    on<ManasFormSubmitEvent>(_onSubmit, transformer: droppable());
    on<ManasFormDeleteEvent>(_onDelete, transformer: droppable());
  }

  Future<void> _onLoad(
      ManasFormLoadEvent event, Emitter<ManasFormState> emit) async {
    emit(state.copyWith(status: ManasFormStatus.loading));

    // Search pool = every Brahma note: own (authored) notes ∪ drafts ∪ saved
    // notes — same data for create and edit modes. Own notes are loaded first,
    // then drafts; saved entries override by id so a note that is both authored
    // and saved shows the saved kind. Draft ids (local UUIDs) never collide
    // with the 64-hex event ids of own/saved notes.
    final ownPubkey = (await _getActiveUser.call())
        .fold<String?>((_) => null, (u) => u.pubkeyHex);
    final ownNotes = ownPubkey == null
        ? const <NoteEntity>[]
        : (await _getOwnNotes.call(ownPubkey))
            .fold<List<NoteEntity>>((_) => const [], (l) => l);
    final drafts = (await _getDrafts.call())
        .fold<List<DraftEntity>>((_) => const [], (l) => l);
    final savedNotes = (await _getAllSaved.call())
        .fold<List<SavedNoteEntity>>((_) => const [], (l) => l);

    final byId = <String, _PoolNote>{};
    for (final n in ownNotes) {
      byId[n.id] = _PoolNote(n.id, n.content, ManasNoteKind.own);
    }
    for (final d in drafts) {
      byId[d.draftId] = _PoolNote(d.draftId, d.content, ManasNoteKind.draft);
    }
    for (final s in savedNotes) {
      byId[s.eventId] = _PoolNote(s.eventId, s.content, ManasNoteKind.saved);
    }
    _pool = byId.values.toList();

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
    for (final n in _pool) {
      if (!n.content.toLowerCase().contains(lower)) continue;
      results.add(ManasNotePreview(
        noteId: n.noteId,
        preview: _shortenPreview(n.content),
        kind: n.kind,
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
    for (final n in _pool) {
      if (n.noteId == noteId) {
        return ManasNotePreview(
          noteId: noteId,
          preview: _shortenPreview(n.content),
          kind: n.kind,
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
