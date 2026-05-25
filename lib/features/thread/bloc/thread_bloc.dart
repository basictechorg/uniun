import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

part 'thread_event.dart';
part 'thread_state.dart';

// ── BLoC ─────────────────────────────────────────────────────────────────────

@injectable
class ThreadBloc extends Bloc<ThreadEvent, ThreadState> {
  final GetNoteByIdUseCase _getNoteById;
  final GetRepliesUseCase _getReplies;
  final PublishNoteUseCase _publishNote;
  final GetProfileUseCase _getProfile;
  final GetActiveUserKeysUseCase _getActiveUserKeys;
  final EmbedAndStoreNoteUseCase _embedAndStore;
  final GetAllSavedNotesUseCase _getAllSavedNotes;

  ThreadBloc(
    this._getNoteById,
    this._getReplies,
    this._publishNote,
    this._getProfile,
    this._getActiveUserKeys,
    this._embedAndStore,
    this._getAllSavedNotes,
  ) : super(const ThreadState()) {
    on<LoadThreadEvent>(_onLoad, transformer: droppable());
    on<UpdateReplyTextEvent>(_onUpdateText);
    on<SetReplyTargetEvent>(_onSetTarget);
    on<PostReplyEvent>(_onPost, transformer: droppable());
    on<SwitchTabEvent>(_onSwitchTab);
    on<ExpandReplyEvent>(_onExpand, transformer: sequential());
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _onLoad(
    LoadThreadEvent event,
    Emitter<ThreadState> emit,
  ) async {
    emit(state.copyWith(status: ThreadStatus.loading));

    // ── Phase 1: fetch root note ─────────────────────────────────────────────
    final rootResult = await _getNoteById.call(event.noteId);
    if (rootResult.isLeft()) {
      emit(state.copyWith(
        status: ThreadStatus.error,
        errorMessage: rootResult.fold((f) => f.toMessage(), (_) => ''),
      ));
      return;
    }
    final rootNote = rootResult.getOrElse(() => throw StateError(''));

    // ── Phase 2: fetch root profile + direct replies + parent chain in parallel
    final profiles = <String, ProfileEntity>{};

    final rootProfileFuture = _getProfile.call(rootNote.authorPubkey);

    // When opened from Saved Notes — load from savedNoteModels directly so
    // cachedReplyCount is the saved-only count (not the total relay count).
    Set<String> savedOnlyIds = {};
    List<NoteEntity> directReplies;
    if (event.savedOnly) {
      final savedResult = await _getAllSavedNotes.call();
      final allSaved = savedResult.fold((_) => <SavedNoteEntity>[], (n) => n);
      savedOnlyIds = {for (final s in allSaved) s.eventId};
      directReplies = allSaved
          .where((s) =>
              s.eventId != event.noteId &&
              s.eTagRefs.contains(event.noteId))
          .map((s) => s.toNoteEntity(savedEventIds: savedOnlyIds))
          .toList()
        ..sort((a, b) => a.created.compareTo(b.created));
    } else {
      final repliesResult = await _getReplies.call(event.noteId);
      directReplies = repliesResult.fold((_) => <NoteEntity>[], (r) => r);
    }

    final rootProfile = await rootProfileFuture;
    rootProfile.fold((_) {}, (p) => profiles[p.pubkey] = p);

    // Load profiles for direct replies — all parallel
    await Future.wait(directReplies.map((reply) async {
      final pr = await _getProfile.call(reply.authorPubkey);
      pr.fold((_) {}, (p) => profiles[p.pubkey] = p);
    }));

    // ── Load mention refs (outgoing e-tag mentions — rendered above the root
    //    note as sibling "parents" that this note references) ─────────────────
    final mentionIds = rootNote.eTagRefs
        .where((id) => id != rootNote.rootEventId && id != rootNote.replyToEventId)
        .where((id) => !event.savedOnly || savedOnlyIds.contains(id))
        .toList();
    final mentionedNotes = <NoteEntity>[];
    if (mentionIds.isNotEmpty) {
      final mentionResults = await Future.wait(
        mentionIds.map((id) => _getNoteById.call(id)),
      );
      for (final r in mentionResults) {
        r.fold((_) {}, mentionedNotes.add);
      }
      // Load profiles for mention authors in parallel
      await Future.wait(mentionedNotes.map((m) async {
        if (!profiles.containsKey(m.authorPubkey)) {
          final pr = await _getProfile.call(m.authorPubkey);
          pr.fold((_) {}, (p) => profiles[p.pubkey] = p);
        }
      }));
    }

    // ── Load immediate parent (1 level only, no grandparent) ─────────────────
    final parentChain = <NoteEntity>[];
    final immediateParentId = rootNote.replyToEventId;
    if (immediateParentId != null) {
      final pr = await _getNoteById.call(immediateParentId);
      pr.fold((_) {}, (parent) {
        parentChain.add(parent);
      });
      if (parentChain.isNotEmpty &&
          !profiles.containsKey(parentChain.first.authorPubkey)) {
        final pfr = await _getProfile.call(parentChain.first.authorPubkey);
        pfr.fold((_) {}, (p) => profiles[p.pubkey] = p);
      }
    }

    emit(state.copyWith(
      rootNote: rootNote,
      parentChain: parentChain,
      profiles: Map.from(profiles),
      replies: directReplies,
      nestedReplies: const {},
      mentionedNotes: mentionedNotes,
      status: ThreadStatus.loaded,
      hasUnread: event.hasUnread,
      savedOnly: event.savedOnly,
      savedOnlyIds: savedOnlyIds,
    ));
  }

  // ── Lazy expand (on-demand, beyond BFS depth limit) ───────────────────────

  Future<void> _onExpand(
    ExpandReplyEvent event,
    Emitter<ThreadState> emit,
  ) async {
    // Already loaded — nothing to do
    if (state.nestedReplies.containsKey(event.replyId)) return;

    List<NoteEntity> children;

    if (state.savedOnly) {
      // In saved-only mode: only show nested notes that are also saved, and
      // use SavedNoteEntity.toNoteEntity() so cachedReplyCount is saved-only.
      final savedResult = await _getAllSavedNotes.call();
      final allSaved = savedResult.fold(
        (_) => <SavedNoteEntity>[],
        (n) => n,
      );
      final savedIds = {for (final s in allSaved) s.eventId};
      children = allSaved
          .where((s) =>
              s.eventId != event.replyId &&
              s.eTagRefs.contains(event.replyId))
          .map((s) => s.toNoteEntity(savedEventIds: savedIds))
          .toList()
        ..sort((a, b) => a.created.compareTo(b.created));
    } else {
      final nr = await _getReplies.call(event.replyId);
      if (nr.isLeft()) return;
      children = nr.getOrElse(() => []);
    }

    if (children.isEmpty) return;

    final profiles = Map<String, ProfileEntity>.from(state.profiles);

    await Future.wait(children.map((child) async {
      if (!profiles.containsKey(child.authorPubkey)) {
        final pr = await _getProfile.call(child.authorPubkey);
        pr.fold((_) {}, (p) => profiles[p.pubkey] = p);
      }
    }));

    final updated = Map<String, List<NoteEntity>>.from(state.nestedReplies);
    updated[event.replyId] = children;

    if (!emit.isDone) {
      emit(state.copyWith(
        nestedReplies: updated,
        profiles: profiles,
      ));
    }
  }

  // ── Reply composer ────────────────────────────────────────────────────────

  void _onUpdateText(UpdateReplyTextEvent event, Emitter<ThreadState> emit) {
    emit(state.copyWith(
      replyText: event.text,
      postStatus: ThreadPostStatus.idle,
    ));
  }

  void _onSetTarget(SetReplyTargetEvent event, Emitter<ThreadState> emit) {
    emit(state.copyWith(
      replyingToId: event.replyToId,
      replyingToName: event.replyToName,
      postStatus: ThreadPostStatus.idle,
    ));
  }

  Future<void> _onPost(
    PostReplyEvent event,
    Emitter<ThreadState> emit,
  ) async {
    if (!state.canPost || state.rootNote == null) return;
    emit(state.copyWith(postStatus: ThreadPostStatus.posting));

    final keysResult = await _getActiveUserKeys.call();
    if (keysResult.isLeft()) {
      emit(state.copyWith(
        postStatus: ThreadPostStatus.error,
        errorMessage: keysResult.fold((f) => f.toMessage(), (_) => ''),
      ));
      return;
    }
    final keys = keysResult.getOrElse(() => throw StateError('unreachable'));

    final rootId = state.rootNote!.id;
    final replyToId = state.replyingToId ?? rootId;

    // Build NIP-10 tags
    final tags = <List<String>>[
      ['e', rootId, '', 'root'],
      if (replyToId != rootId) ['e', replyToId, '', 'reply'],
    ];

    // Sign with user's private key
    late final Event signed;
    try {
      signed = Event.from(
        kind: 1,
        tags: tags,
        content: state.replyText.trim(),
        privkey: keys.privkeyHex,
      );
    } catch (e) {
      emit(state.copyWith(
        postStatus: ThreadPostStatus.error,
        errorMessage: 'Signing failed: $e',
      ));
      return;
    }

    final note = NoteEntity(
      id: signed.id,
      sig: signed.sig,
      authorPubkey: keys.pubkeyHex,
      content: signed.content,
      type: NoteType.text,
      eTagRefs: [rootId, if (replyToId != rootId) replyToId],
      pTagRefs: const [],
      tTags: const [],
      created: DateTime.fromMillisecondsSinceEpoch(signed.createdAt * 1000),
      isSeen: true,
      rootEventId: rootId,
      replyToEventId: replyToId,
    );

    final result = await _publishNote.call(note);
    result.fold(
      (f) => emit(state.copyWith(
        postStatus: ThreadPostStatus.error,
        errorMessage: f.toMessage(),
      )),
      (published) {
        // Fire-and-forget: embed own authored reply for RAG.
        unawaited(_embedAndStore.call((published.id, published.content)));
        final updatedState = state.copyWith(
          replyText: '',
          replyingToId: null,
          replyingToName: null,
          postStatus: ThreadPostStatus.posted,
        );
        if (replyToId == rootId) {
          emit(updatedState.copyWith(
            replies: [...state.replies, published],
          ));
        } else {
          final updatedNested =
              Map<String, List<NoteEntity>>.from(state.nestedReplies);
          updatedNested[replyToId] = [
            ...(updatedNested[replyToId] ?? []),
            published,
          ];
          emit(updatedState.copyWith(
            nestedReplies: updatedNested,
          ));
        }
      },
    );
  }

  void _onSwitchTab(SwitchTabEvent event, Emitter<ThreadState> emit) {
    emit(state.copyWith(activeTab: event.index));
  }
}
