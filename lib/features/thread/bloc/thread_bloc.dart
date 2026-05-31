import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';
import 'package:uniun/domain/usecases/post_reply_usecase.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';

part 'thread_event.dart';
part 'thread_state.dart';

/// Resolver-backed thread bloc. Reads a note from *any* collection by id and
/// posts replies routed by source — one bloc for feed/channel/private/DM.
@injectable
class ThreadBloc extends Bloc<ThreadEvent, ThreadState> {
  final NoteResolverRepository _resolver;
  final PostReplyUseCase _postReply;
  final GetProfileUseCase _getProfile;
  final GetAllSavedNotesUseCase _getAllSavedNotes;

  ThreadBloc(
    this._resolver,
    this._postReply,
    this._getProfile,
    this._getAllSavedNotes,
  ) : super(const ThreadState()) {
    on<LoadThreadEvent>(_onLoad, transformer: droppable());
    on<PostReplyEvent>(_onPost, transformer: droppable());
  }

  Future<void> _onLoad(LoadThreadEvent event, Emitter<ThreadState> emit) async {
    emit(state.copyWith(status: ThreadStatus.loading));

    final rootResult = await _resolver.resolveById(event.noteId);
    if (rootResult.isLeft()) {
      emit(state.copyWith(
        status: ThreadStatus.error,
        errorMessage: rootResult.fold((f) => f.toMessage(), (_) => ''),
      ));
      return;
    }
    final root = rootResult.getOrElse(() => throw StateError('unreachable'));
    final rootNote = root.note;

    // Parent (NIP-10 reply marker) and outgoing mention refs.
    final parentNotes = <NoteEntity>[];
    if (rootNote.replyToEventId != null) {
      final p = await _resolver.resolveNoteById(rootNote.replyToEventId!);
      p.fold((_) {}, (note) {
        if (note != null) parentNotes.add(note);
      });
    }

    final mentionIds = rootNote.eTagRefs
        .where((id) =>
            id != rootNote.rootEventId && id != rootNote.replyToEventId)
        .toList();
    final mentionedNotes = mentionIds.isEmpty
        ? <NoteEntity>[]
        : (await _resolver.resolveMany(mentionIds))
            .fold((_) => <NoteEntity>[], (n) => n);

    var replies = (await _resolver.resolveReplies(rootNote.id))
        .fold((_) => <NoteEntity>[], (r) => r);

    // Saved-only mode (feed): keep replies that are themselves saved.
    if (event.savedOnly && root.source == NoteSource.feed) {
      final saved = (await _getAllSavedNotes.call())
          .fold((_) => <SavedNoteEntity>[], (n) => n);
      final savedIds = {for (final s in saved) s.eventId};
      replies = replies.where((r) => savedIds.contains(r.id)).toList();
    }

    // Profiles for every visible author.
    final profiles = <String, ProfileEntity>{};
    final pubkeys = {
      rootNote.authorPubkey,
      for (final n in parentNotes) n.authorPubkey,
      for (final n in mentionedNotes) n.authorPubkey,
      for (final n in replies) n.authorPubkey,
    };
    await Future.wait(pubkeys.map((pk) async {
      final pr = await _getProfile.call(pk);
      pr.fold((_) {}, (p) => profiles[p.pubkey] = p);
    }));

    emit(state.copyWith(
      status: ThreadStatus.loaded,
      root: root,
      parentNotes: parentNotes,
      mentionedNotes: mentionedNotes,
      replies: replies,
      profiles: profiles,
      savedOnly: event.savedOnly,
      postStatus: ThreadPostStatus.idle,
    ));
  }

  Future<void> _onPost(PostReplyEvent event, Emitter<ThreadState> emit) async {
    final root = state.root;
    if (root == null || event.content.trim().isEmpty) return;

    emit(state.copyWith(postStatus: ThreadPostStatus.posting));

    final result = await _postReply.call(PostReplyParams(
      root: root,
      content: event.content.trim(),
      mentionRefs: event.mentionRefs,
    ));

    await result.fold(
      (f) async => emit(state.copyWith(
        postStatus: ThreadPostStatus.error,
        errorMessage: f.toMessage(),
      )),
      (_) async {
        // Reload so the new reply appears under the root.
        add(LoadThreadEvent(root.note.id, savedOnly: state.savedOnly));
      },
    );
  }
}
