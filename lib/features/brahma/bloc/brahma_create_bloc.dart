import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/features/brahma/utils/nostr_event_utils.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

part 'brahma_create_event.dart';
part 'brahma_create_state.dart';

@injectable
class BrahmaCreateBloc extends Bloc<BrahmaCreateEvent, BrahmaCreateState> {
  final GetActiveUserKeysUseCase _getActiveUserKeys;
  final PublishNoteUseCase _publishUseCase;
  final PublishMediaNoteUseCase _publishMediaUseCase;
  final UploadMediaUseCase _uploadMedia;
  final SaveLocalMediaUseCase _saveLocalMedia;
  final ReadLocalMediaUseCase _readLocalMedia;
  final EmbedAndStoreNoteUseCase _embedAndStore;
  final SaveDraftUseCase _saveDraft;
  final GetDraftsUseCase _getDrafts;
  final GetDraftByIdUseCase _getDraftById;
  final DeleteDraftUseCase _deleteDraft;
  final SearchNotesUseCase _searchNotes;
  final GetNoteByIdUseCase _getNoteById;

  BrahmaCreateBloc(
    this._getActiveUserKeys,
    this._publishUseCase,
    this._publishMediaUseCase,
    this._uploadMedia,
    this._saveLocalMedia,
    this._readLocalMedia,
    this._embedAndStore,
    this._saveDraft,
    this._getDrafts,
    this._getDraftById,
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
    on<AttachMediaEvent>(_onAttachMedia, transformer: sequential());
    on<RemoveAttachedMediaEvent>(_onRemoveAttachedMedia);
    on<RestoreDraftMediaEvent>(_onRestoreDraftMedia, transformer: sequential());
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

    // 2. Upload any pending attachments now (deferred from attach time). A
    //    failed upload aborts the publish but leaves the picks in state so the
    //    user can retry.
    final hashtags = extractHashtags(content);
    final mentionIds = state.selectedMentions.map((m) => m.id).toList();

    final attached = <MediaBlobEntity>[];
    for (final media in state.pendingMedia) {
      final up = await _uploadMedia.call(UploadMediaInput(
        bytes: media.bytes,
        mime: media.mime,
        filename: media.filename,
        blurhash: media.blurhash,
        width: media.width,
        height: media.height,
      ));
      final blob = up.fold((_) => null, (b) => b);
      if (blob == null) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: up.fold((f) => f.toMessage(), (_) => ''),
        ));
        return;
      }
      attached.add(blob);
    }

    final tags = buildNoteTags(
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
      mentionIds: mentionIds,
      hashtags: hashtags,
    );
    if (attached.isNotEmpty) {
      tags.addAll(buildImetaTags(attached));
    }

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
    ).copyWith(
      type: attached.any((b) => b.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text,
      attachments: attached,
    );

    // 5. Publish — both paths now use the same shaped serializer; the
    //    typed imeta column makes raw-passthrough unnecessary.
    final result = attached.isEmpty
        ? await _publishUseCase.call(note)
        : await _publishMediaUseCase.call(PublishMediaNoteInput(
            note: note,
            attachments: attached,
          ));
    result.fold(
      (f) => emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: f.toMessage(),
      )),
      (_) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.success,
          selectedMentions: [],
          pendingMedia: [],
        ));
        // Fire-and-forget: embed this note for RAG (no-op if model not ready yet).
        unawaited(_embedAndStore.call((signedEvent.id, signedEvent.content)));
      },
    );
  }

  // Imeta tag construction lives in lib/core/notes/imeta_builder.dart so
  // every surface emits the same NIP-92 layout.

  void _onAttachMedia(
    AttachMediaEvent event,
    Emitter<BrahmaCreateState> emit,
  ) {
    // No upload here — the blob is pushed to Blossom on submit. Just hold the
    // prepared (dimensions + blurhash already computed) pick, deduped by hash.
    if (state.pendingMedia.any((m) => m.sha256 == event.media.sha256)) return;
    emit(state.copyWith(
      pendingMedia: [...state.pendingMedia, event.media],
    ));
  }

  void _onRemoveAttachedMedia(
    RemoveAttachedMediaEvent event,
    Emitter<BrahmaCreateState> emit,
  ) {
    emit(state.copyWith(
      pendingMedia: state.pendingMedia
          .where((m) => m.sha256 != event.sha256)
          .toList(),
    ));
  }

  Future<void> _onRestoreDraftMedia(
    RestoreDraftMediaEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    // Read each staged blob's bytes back from the cache and rebuild the
    // PickedMedia so the composer shows the thumbnails. Anything no longer on
    // disk is silently dropped.
    final picks = <PickedMedia>[];
    for (final blob in event.attachments) {
      final bytesRes = await _readLocalMedia.call(blob.sha256);
      final bytes = bytesRes.fold((_) => null, (b) => b);
      if (bytes == null) continue;
      picks.add(PickedMedia(
        bytes: bytes,
        mime: blob.mime,
        filename: blob.filename ?? blob.sha256,
        sha256: blob.sha256,
        width: blob.dim?.width,
        height: blob.dim?.height,
        blurhash: blob.blurhash,
      ));
    }
    emit(state.copyWith(pendingMedia: picks));
  }

  Future<void> _onSaveDraft(
    SaveDraftEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    final content = event.content.trim();
    if (content.isEmpty && state.pendingMedia.isEmpty) return;

    // Stage attached media on-device only — no Blossom upload while a draft
    // (that happens at publish). A staging failure aborts the save but keeps
    // the picks so the user can retry.
    final staged = <MediaBlobEntity>[];
    for (final media in state.pendingMedia) {
      final res = await _saveLocalMedia.call(SaveLocalMediaInput(
        bytes: media.bytes,
        mime: media.mime,
        filename: media.filename,
        blurhash: media.blurhash,
        width: media.width,
        height: media.height,
      ));
      final blob = res.fold((_) => null, (b) => b);
      if (blob == null) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: res.fold((f) => f.toMessage(), (_) => ''),
        ));
        return;
      }
      staged.add(blob);
    }

    final hashtags = extractHashtags(content);
    final mentionIds = state.selectedMentions.map((m) => m.id).toList();

    // Editing an existing draft updates it in place (same id + createdAt) so
    // re-saving doesn't spawn a duplicate or lose its media.
    final existing = event.draftId != null
        ? state.drafts.where((d) => d.draftId == event.draftId).firstOrNull
        : null;

    final draft = DraftEntity(
      draftId: event.draftId ?? const Uuid().v4(),
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
      attachments: staged,
      createdAt: existing?.createdAt ?? DateTime.now(),
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

    // Fetch the draft fresh — this bloc instance may not be the one that saved
    // it (graph panel vs. compose page hold separate instances), so its cached
    // `state.drafts` can be stale. The fetched copy carries current mentions +
    // staged (cache-enriched) media.
    final draftRes = await _getDraftById.call(event.draftId);
    final draft = draftRes.fold((_) => null, (d) => d);
    final mentionIds = draft != null
        ? draft.eTagRefs
            .where((id) => id != event.rootEventId && id != event.replyToEventId)
            .toList()
        : <String>[];

    emit(state.copyWith(status: BrahmaCreateStatus.submitting));

    // Upload the draft's locally-staged media to Blossom now (deferred from
    // save). Read each blob's bytes back from the cache → upload → imeta. A
    // failure aborts the publish and leaves the draft intact.
    final attached = <MediaBlobEntity>[];
    for (final blob in draft?.attachments ?? const <MediaBlobEntity>[]) {
      final bytesRes = await _readLocalMedia.call(blob.sha256);
      final bytes = bytesRes.fold((_) => null, (b) => b);
      if (bytes == null) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: 'Draft media is no longer available on this device.',
        ));
        return;
      }
      final up = await _uploadMedia.call(UploadMediaInput(
        bytes: bytes,
        mime: blob.mime,
        filename: blob.filename,
        blurhash: blob.blurhash,
        width: blob.dim?.width,
        height: blob.dim?.height,
      ));
      final uploaded = up.fold((_) => null, (b) => b);
      if (uploaded == null) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: up.fold((f) => f.toMessage(), (_) => ''),
        ));
        return;
      }
      attached.add(uploaded);
    }

    final hashtags = extractHashtags(event.content);
    final tags = buildNoteTags(
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
      mentionIds: mentionIds,
      hashtags: hashtags,
    );
    if (attached.isNotEmpty) {
      tags.addAll(buildImetaTags(attached));
    }

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
    ).copyWith(
      type: attached.any((b) => b.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text,
      attachments: attached,
    );

    // Publish — media path when the draft carried attachments.
    final publishResult = attached.isEmpty
        ? await _publishUseCase.call(note)
        : await _publishMediaUseCase.call(PublishMediaNoteInput(
            note: note,
            attachments: attached,
          ));
    if (publishResult.isLeft()) {
      emit(state.copyWith(
        status: BrahmaCreateStatus.error,
        errorMessage: publishResult.fold((f) => f.toMessage(), (_) => ''),
      ));
      return;
    }

    // Published — delete the draft, then signal success. The delete is awaited
    // (not fire-and-forget) so we never `add`/`emit` after the surface disposed
    // this bloc on navigation; the `isClosed` guard covers a mid-await dispose.
    await _deleteDraft.call(event.draftId);
    unawaited(_embedAndStore.call((signedEvent.id, signedEvent.content)));
    if (!isClosed) {
      emit(state.copyWith(status: BrahmaCreateStatus.success));
    }
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
