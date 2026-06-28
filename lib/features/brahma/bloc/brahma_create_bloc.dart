import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dartz/dartz.dart';
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
  final MarkDraftPublishedUseCase _markDraftPublished;
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
    this._markDraftPublished,
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
    on<AddDraftMentionEvent>(_onAddDraftMention);
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

    // 2. Publish any referenced drafts first (chain mode), or drop them
    //    silently (default). The resolved map carries UUID → event id for
    //    each newly-published draft + any already-published tombstones we
    //    encountered along the way.
    final draftDepUuids =
        state.selectedDraftMentions.map((d) => d.draftId).toList();
    var resolvedDraftRefs = <String, String>{};
    if (draftDepUuids.isNotEmpty && event.publishChain) {
      final chainRes = await _publishDraftDependencies(draftDepUuids);
      final err = chainRes.fold((m) => m, (_) => null);
      if (err != null) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: err,
        ));
        return;
      }
      resolvedDraftRefs = chainRes.getOrElse(() => const {});
    }

    // 3. Upload any pending attachments now (deferred from attach time). A
    //    failed upload aborts the publish but leaves the picks in state so the
    //    user can retry.
    final hashtags = extractHashtags(content);
    final noteMentionIds = state.selectedMentions.map((m) => m.id).toList();
    final resolvedDraftIds = <String>[
      for (final uuid in draftDepUuids)
        if (resolvedDraftRefs[uuid] != null) resolvedDraftRefs[uuid]!,
    ];
    final mentionIds = [...noteMentionIds, ...resolvedDraftIds];

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
          selectedDraftMentions: [],
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

    final draftRefIds =
        state.selectedDraftMentions.map((d) => d.draftId).toList();

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
      draftRefIds: draftRefIds,
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
    emit(state.copyWith(status: BrahmaCreateStatus.submitting));

    if (event.publishChain) {
      await _publishDraftChain(event, emit);
      return;
    }

    final res = await _publishOneDraft(
      draftId: event.draftId,
      content: event.content,
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
      resolvedDraftRefs: const {},
    );
    res.fold(
      (msg) {
        if (!isClosed) {
          emit(state.copyWith(
            status: BrahmaCreateStatus.error,
            errorMessage: msg,
          ));
        }
      },
      (_) {
        if (!isClosed) {
          emit(state.copyWith(status: BrahmaCreateStatus.success));
        }
      },
    );
  }

  /// Publishes a single draft and returns the freshly-minted event id (Right)
  /// or an error message (Left). Status is NOT emitted here — callers manage
  /// the surrounding state machine (chain publish wraps many calls).
  ///
  /// [resolvedDraftRefs] maps UUIDs in this draft's `draftRefIds` to the
  /// event ids of just-published children — those event ids are appended to
  /// the Kind-1's `e` mention tags. UUIDs not in the map are silently dropped.
  Future<Either<String, String>> _publishOneDraft({
    required String draftId,
    required String content,
    String? rootEventId,
    String? replyToEventId,
    required Map<String, String> resolvedDraftRefs,
  }) async {
    final keysResult = await _getActiveUserKeys.call();
    if (keysResult.isLeft()) {
      return Left(keysResult.fold((f) => f.toMessage(), (_) => ''));
    }
    final keys = keysResult.getOrElse(() => throw StateError('unreachable'));
    final privkeyHex = keys.privkeyHex;
    final pubkeyHex = keys.pubkeyHex;

    final draftRes = await _getDraftById.call(draftId);
    final draft = draftRes.fold((_) => null, (d) => d);
    if (draft == null) return const Left('Draft no longer exists.');

    // Note-mention ids carried verbatim (already real event ids), filtered to
    // skip root/reply so they're not duplicated.
    final noteMentionIds = draft.eTagRefs
        .where((id) => id != rootEventId && id != replyToEventId)
        .toList();
    // Resolved draft-mention ids (UUID → event id from a chain publish).
    final resolvedIds = <String>[
      for (final uuid in draft.draftRefIds)
        if (resolvedDraftRefs[uuid] != null) resolvedDraftRefs[uuid]!,
    ];
    final mentionIds = [...noteMentionIds, ...resolvedIds];

    // Upload the draft's locally-staged media to Blossom now (deferred from
    // save).
    final attached = <MediaBlobEntity>[];
    for (final blob in draft.attachments) {
      final bytesRes = await _readLocalMedia.call(blob.sha256);
      final bytes = bytesRes.fold((_) => null, (b) => b);
      if (bytes == null) {
        return const Left('Draft media is no longer available on this device.');
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
        return Left(up.fold((f) => f.toMessage(), (_) => ''));
      }
      attached.add(uploaded);
    }

    final hashtags = extractHashtags(content);
    final tags = buildNoteTags(
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      mentionIds: mentionIds,
      hashtags: hashtags,
    );
    if (attached.isNotEmpty) {
      tags.addAll(buildImetaTags(attached));
    }

    late final Event signedEvent;
    try {
      signedEvent = signNostrEvent(
          content: content, tags: tags, privkeyHex: privkeyHex);
    } catch (e) {
      return Left('Signing failed: $e');
    }

    final eTagRefs = [
      if (rootEventId != null) rootEventId,
      if (replyToEventId != null) replyToEventId,
      ...mentionIds,
    ];
    final note = noteEntityFromEvent(
      event: signedEvent,
      pubkeyHex: pubkeyHex,
      eTagRefs: eTagRefs,
      tTags: hashtags,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
    ).copyWith(
      type: attached.any((b) => b.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text,
      attachments: attached,
    );

    final publishResult = attached.isEmpty
        ? await _publishUseCase.call(note)
        : await _publishMediaUseCase.call(PublishMediaNoteInput(
            note: note,
            attachments: attached,
          ));
    if (publishResult.isLeft()) {
      return Left(publishResult.fold((f) => f.toMessage(), (_) => ''));
    }

    // Tombstone the draft: save it back with `publishedAsEventId` set so other
    // drafts on this and remote devices can resolve UUID → event id. The
    // repository republishes the NIP-37 wrap so the mapping syncs; cleanup
    // expires the tombstone after the retention window.
    await _markDraftPublished.call(MarkDraftPublishedInput(
      draftId: draftId,
      eventId: signedEvent.id,
    ));
    unawaited(_embedAndStore.call((signedEvent.id, signedEvent.content)));
    return Right(signedEvent.id);
  }

  /// Publish-chain entry point for an existing draft: publishes the draft's
  /// dependency closure bottom-up, then the draft itself with rewritten `e`
  /// tags (so its link to the children survives).
  Future<void> _publishDraftChain(
    PublishDraftEvent event,
    Emitter<BrahmaCreateState> emit,
  ) async {
    // Publish every dependency first (children only).
    final draftRes = await _getDraftById.call(event.draftId);
    final root = draftRes.fold((_) => null, (d) => d);
    if (root == null) {
      if (!isClosed) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: 'Draft no longer exists.',
        ));
      }
      return;
    }
    final depRes = await _publishDraftDependencies(root.draftRefIds);
    final err = depRes.fold((m) => m, (_) => null);
    if (err != null) {
      if (!isClosed) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: err,
        ));
      }
      return;
    }
    final resolved = depRes.getOrElse(() => const {});

    // Now the root itself.
    final rootRes = await _publishOneDraft(
      draftId: event.draftId,
      content: event.content,
      rootEventId: event.rootEventId,
      replyToEventId: event.replyToEventId,
      resolvedDraftRefs: resolved,
    );
    final rootErr = rootRes.fold((m) => m, (_) => null);
    if (rootErr != null) {
      if (!isClosed) {
        emit(state.copyWith(
          status: BrahmaCreateStatus.error,
          errorMessage: rootErr,
        ));
      }
      return;
    }
    if (!isClosed) {
      emit(state.copyWith(status: BrahmaCreateStatus.success));
    }
  }

  /// Publishes the *dependency closure* of the given draft UUIDs (BFS over
  /// `draftRefIds`, topo-sorted, leaves first), and returns a map of every
  /// involved draft UUID → its event id. Already-published tombstones in the
  /// closure contribute their existing mapping without being republished.
  /// Cycles or partial failures return Left.
  Future<Either<String, Map<String, String>>> _publishDraftDependencies(
    List<String> rootUuids,
  ) async {
    // 1. Collect reachable drafts via BFS starting from the given roots.
    final reachable = <String, DraftEntity>{};
    final stack = [...rootUuids];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (reachable.containsKey(id)) continue;
      final res = await _getDraftById.call(id);
      final d = res.fold((_) => null, (x) => x);
      if (d == null) continue;
      reachable[id] = d;
      // Tombstones (already published) contribute their mapping but no further
      // children — their published event is already on the relay.
      if (d.publishedAsEventId != null) continue;
      for (final ref in d.draftRefIds) {
        if (!reachable.containsKey(ref)) stack.add(ref);
      }
    }

    // 2. Topo-sort the unpublished subset; the published tombstones are
    // already terminal.
    final unpublished = {
      for (final e in reachable.entries)
        if (e.value.publishedAsEventId == null) e.key: e.value,
    };
    final order = _topoSort(unpublished);
    if (order == null) {
      return const Left(
          'Circular draft references — publish one without the back-link first.');
    }

    // 3. Seed the resolved map with tombstones.
    final resolved = <String, String>{
      for (final e in reachable.values)
        if (e.publishedAsEventId != null) e.draftId: e.publishedAsEventId!,
    };

    // 4. Publish in dependency-first order, threading the growing resolved
    // map into each child's `_publishOneDraft` call.
    var published = 0;
    for (final id in order) {
      final draft = unpublished[id]!;
      final res = await _publishOneDraft(
        draftId: id,
        content: draft.content,
        rootEventId: draft.rootEventId,
        replyToEventId: draft.replyToEventId,
        resolvedDraftRefs: resolved,
      );
      final failureMsg = res.fold((m) => m, (_) => null);
      if (failureMsg != null) {
        return Left(
            'Published $published of ${order.length} dependent drafts — $failureMsg');
      }
      resolved[id] = res.getOrElse(() => '');
      published++;
    }
    return Right(resolved);
  }

  /// Kahn's algorithm over the draft → draftRefIds graph (edges point from a
  /// draft to its dependencies). Returns ids in dependency-first order, or
  /// null if a cycle exists.
  List<String>? _topoSort(Map<String, DraftEntity> nodes) {
    final indegree = <String, int>{for (final id in nodes.keys) id: 0};
    for (final d in nodes.values) {
      for (final ref in d.draftRefIds) {
        // Only count edges to nodes we're publishing (skip dangling /
        // already-published refs).
        if (indegree.containsKey(ref)) {
          indegree[d.draftId] = (indegree[d.draftId] ?? 0) + 1;
        }
      }
    }
    final ready = [
      for (final e in indegree.entries)
        if (e.value == 0) e.key,
    ];
    final out = <String>[];
    while (ready.isNotEmpty) {
      final id = ready.removeLast();
      out.add(id);
      // Find anyone whose only remaining dependency was `id` and release them.
      for (final other in nodes.values) {
        if (other.draftRefIds.contains(id) &&
            indegree.containsKey(other.draftId)) {
          indegree[other.draftId] = indegree[other.draftId]! - 1;
          if (indegree[other.draftId] == 0) ready.add(other.draftId);
        }
      }
    }
    if (out.length != nodes.length) return null; // cycle
    return out;
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

  void _onAddDraftMention(
      AddDraftMentionEvent event, Emitter<BrahmaCreateState> emit) {
    final already = state.selectedDraftMentions
        .any((d) => d.draftId == event.draft.draftId);
    if (already) return;
    emit(state.copyWith(
      selectedDraftMentions: [...state.selectedDraftMentions, event.draft],
    ));
  }

  void _onRemoveMention(
      RemoveMentionEvent event, Emitter<BrahmaCreateState> emit) {
    // The id can be either a note event id or a draft UUID — strip from both
    // lists since they share an identifier namespace at the UI layer.
    emit(state.copyWith(
      selectedMentions:
          state.selectedMentions.where((m) => m.id != event.noteId).toList(),
      selectedDraftMentions: state.selectedDraftMentions
          .where((d) => d.draftId != event.noteId)
          .toList(),
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
    final drafts = <DraftEntity>[];
    for (final id in event.noteIds) {
      final result = await _getNoteById.call(id);
      result.fold((_) {}, (note) => notes.add(note));
    }
    for (final id in event.draftIds) {
      final result = await _getDraftById.call(id);
      result.fold((_) {}, (draft) {
        // Skip tombstones — once a draft has been published it's no longer a
        // valid draft reference; the publish-chain reconciler will rewrite the
        // UUID → event id on the referencing draft separately.
        if (draft.publishedAsEventId == null) drafts.add(draft);
      });
    }
    // Always emit so the picker can also clear all selected mentions.
    emit(state.copyWith(
      selectedMentions: notes,
      selectedDraftMentions: drafts,
    ));
  }

}
