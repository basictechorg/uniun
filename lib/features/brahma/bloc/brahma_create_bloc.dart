import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/features/brahma/utils/nostr_event_utils.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

part 'brahma_create_event.dart';
part 'brahma_create_state.dart';

@injectable
class BrahmaCreateBloc extends Bloc<BrahmaCreateEvent, BrahmaCreateState> {
  final GetActiveUserKeysUseCase _getActiveUserKeys;
  final PublishNoteUseCase _publishUseCase;
  final EmbedAndStoreNoteUseCase _embedAndStore;
  final SaveDraftUseCase _saveDraft;
  final GetDraftsUseCase _getDrafts;
  final DeleteDraftUseCase _deleteDraft;
  final SearchNotesUseCase _searchNotes;
  final GetNoteByIdUseCase _getNoteById;

  BrahmaCreateBloc(
    this._getActiveUserKeys,
    this._publishUseCase,
    this._embedAndStore,
    this._saveDraft,
    this._getDrafts,
    this._deleteDraft,
    this._searchNotes,
    this._getNoteById,
  ) : super(const BrahmaCreateState()) {
    on<SubmitNoteEvent>(_onSubmitNote, transformer: droppable());
    on<SaveDraftEvent>(_onSaveDraft, transformer: droppable());
    on<LoadDraftsEvent>(_onLoadDrafts, transformer: droppable());
    on<DeleteDraftEvent>(_onDeleteDraft, transformer: sequential());
    on<PublishDraftEvent>(_onPublishDraft, transformer: droppable());
    on<ResetBrahmaEvent>(_onReset);
    on<SearchMentionsEvent>(_onSearchMentions, transformer: restartable());
    on<AddMentionEvent>(_onAddMention);
    on<RemoveMentionEvent>(_onRemoveMention);
    on<ClearMentionSearchEvent>(_onClearMentionSearch);
    on<RestoreDraftMentionsEvent>(_onRestoreDraftMentions);
  }

  Future<void> _onSubmitNote(
    SubmitNoteEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    final content = event.content.trim();
    if (content.isEmpty) return;
    emit(state.copyWith(status: BrahmaCreateStatus.submitting));

    // 1. Get signing keys
    final keysResult = await _getActiveUserKeys.call();
    if (keysResult.isLeft()) {
      emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: keysResult.fold((f) => f.toMessage(), (_) => ''),
      ));
      return;
    }
    final keys = keysResult.getOrElse(() => throw StateError('unreachable'));
    final privkeyHex = keys.privkeyHex;
    final pubkeyHex = keys.pubkeyHex;

    // 2. Build tags
    final hashtags = extractHashtags(content);
    final mentionIds = state.selectedMentions.map((m) => m.id).toList();
    final tags = buildNoteTags(
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
      mentionIds: mentionIds,
      hashtags: hashtags,
    );

    // 3. Sign
    late final Event signedEvent;
    try {
      signedEvent = signNostrEvent(
          content: content, tags: tags, privkeyHex: privkeyHex);
    } catch (e) {
      emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: 'Signing failed: $e'));
      return;
    }

    // 4. Build NoteEntity
    final eTagRefs = [
      if (event.rootEventId != null) event.rootEventId!,
      if (event.replyToEventId != null) event.replyToEventId!,
      ...mentionIds,
    ];
    final note = noteEntityFromEvent(
      event: signedEvent,
      pubkeyHex: pubkeyHex,
      eTagRefs: eTagRefs,
      tTags: hashtags,
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
    );

    // 5. Publish: save locally + enqueue for relay
    final result = await _publishUseCase.call(note);
    result.fold(
      (f) => emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: f.toMessage(),
      )),
      (_) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.success,
          selectedMentions: [],
        ));
        // Fire-and-forget: embed this note for RAG (no-op if model not ready yet).
        unawaited(_embedAndStore.call((signedEvent.id, signedEvent.content)));
      },
    );
  }

  Future<void> _onSaveDraft(
    SaveDraftEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    final content = event.content.trim();
    if (content.isEmpty) return;

    final hashtags = extractHashtags(content);
    final mentionIds = state.selectedMentions.map((m) => m.id).toList();

    final draft = DraftEntity(
      draftId: const Uuid().v4(),
      content: content,
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
      eTagRefs: [
        if (event.rootEventId != null) event.rootEventId!,
        if (event.replyToEventId != null) event.replyToEventId!,
        ...mentionIds,
      ],
      pTagRefs: const [],
      tTags: hashtags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _saveDraft.call(draft);
    result.fold(
      (f) => emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: f.toMessage(),
      )),
      (_) {
        emit(state.copyWith(status: BrahmaCreateStatus.draftSaved));
        add(const LoadDraftsEvent());
      },
    );
  }

  Future<void> _onLoadDrafts(
    LoadDraftsEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    emit(state.copyWith(status: BrahmaCreateStatus.loadingDrafts));
    final result = await _getDrafts.call();
    result.fold(
      (f) => emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: f.toMessage(),
      )),
      (drafts) => emit(state.copyWith(
        status: BrahmaCreateStatus.idle,
        drafts: drafts,
      )),
    );
  }

  Future<void> _onDeleteDraft(
    DeleteDraftEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    final result = await _deleteDraft.call(event.draftId);
    result.fold(
      (f) => emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: f.toMessage(),
      )),
      (_) {
        // Reload drafts after deletion
        add(const LoadDraftsEvent());
      },
    );
  }

  Future<void> _onPublishDraft(
    PublishDraftEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    // Publish draft as a note, then delete the draft
    final keysResult = await _getActiveUserKeys.call();
    if (keysResult.isLeft()) {
      emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: keysResult.fold((f) => f.toMessage(), (_) => ''),
      ));
      return;
    }

    final keys = keysResult.getOrElse(() => throw StateError('unreachable'));
    final privkeyHex = keys.privkeyHex;
    final pubkeyHex = keys.pubkeyHex;

    // Build tags — restore mention e-tags from the stored draft
    final draft = state.drafts.where((d) => d.draftId == event.draftId).firstOrNull;
    final mentionIds = draft != null
        ? draft.eTagRefs
            .where((id) => id != event.rootEventId && id != event.replyToEventId)
            .toList()
        : <String>[];

    final hashtags = extractHashtags(event.content);
    final tags = buildNoteTags(
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
      mentionIds: mentionIds,
      hashtags: hashtags,
    );

    // Sign
    late final Event signedEvent;
    try {
      signedEvent = signNostrEvent(
          content: event.content, tags: tags, privkeyHex: privkeyHex);
    } catch (e) {
      emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: 'Signing failed: $e'));
      return;
    }

    // Build NoteEntity
    final eTagRefs = [
      if (event.rootEventId != null) event.rootEventId!,
      if (event.replyToEventId != null) event.replyToEventId!,
      ...mentionIds,
    ];
    final note = noteEntityFromEvent(
      event: signedEvent,
      pubkeyHex: pubkeyHex,
      eTagRefs: eTagRefs,
      tTags: hashtags,
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
    );

    // Publish
    emit(state.copyWith(status: BrahmaCreateStatus.submitting));
    final publishResult = await _publishUseCase.call(note);
    publishResult.fold(
      (f) => emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: f.toMessage(),
      )),
      (_) {
        // Delete draft after successful publish
        _deleteDraft.call(event.draftId).then((_) {
          add(const LoadDraftsEvent());
        });
        emit(state.copyWith(status: BrahmaCreateStatus.success));
        unawaited(_embedAndStore.call((signedEvent.id, signedEvent.content)));
      },
    );
  }

  void _onReset(ResetBrahmaEvent event, Emitter<BrahmaCreateState> emit) {
    emit(const BrahmaCreateState());
  }

  // ── Mention handlers ───────────────────────────────────────────────────────

  Future<void> _onSearchMentions(
    SearchMentionsEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    emit(state.copyWith(isMentionSearching: true));
    final result = await _searchNotes.call(event.query);
    result.fold(
      (_) => emit(state.copyWith(isMentionSearching: false)),
      (notes) => emit(state.copyWith(
        mentionResults: notes,
        isMentionSearching: false,
      )),
    );
  }

  void _onAddMention(AddMentionEvent event, Emitter<BrahmaCreateState> emit) {
    final already = state.selectedMentions.any((m) => m.id == event.note.id);
    if (already) return;
    emit(state.copyWith(
      selectedMentions: [...state.selectedMentions, event.note],
    ));
  }

  void _onRemoveMention(
      RemoveMentionEvent event, Emitter<BrahmaCreateState> emit) {
    emit(state.copyWith(
      selectedMentions:
          state.selectedMentions.where((m) => m.id != event.noteId).toList(),
    ));
  }

  void _onClearMentionSearch(
      ClearMentionSearchEvent event, Emitter<BrahmaCreateState> emit) {
    emit(state.copyWith(mentionResults: [], isMentionSearching: false));
  }

  Future<void> _onRestoreDraftMentions(
    RestoreDraftMentionsEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    final notes = <NoteEntity>[];
    for (final id in event.mentionIds) {
      final result = await _getNoteById.call(id);
      result.fold((_) {}, (note) => notes.add(note));
    }
    // Always emit so the picker can also clear all selected mentions.
    emit(state.copyWith(selectedMentions: notes));
  }

}
