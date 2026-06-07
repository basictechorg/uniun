import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/usecases/blocked_user_usecases.dart';
import 'package:uniun/domain/usecases/deleted_note_usecases.dart';
import 'package:uniun/domain/usecases/followed_note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

part 'note_card_state.dart';

/// Per-card state holder. Owns everything a [NoteCard] needs to render itself:
/// the author profile (reactive), the saved flag, and the follow flag. Follow
/// state is watched reactively from Isar so it stays consistent across every
/// card showing the same note and the drawer's followed-notes list.
@injectable
class NoteCardCubit extends Cubit<NoteCardState> {
  final WatchProfileUseCase _watchProfile;
  final RequestProfileFetchUseCase _requestProfileFetch;
  final IsSavedNoteUseCase _isSavedUseCase;
  final SaveNoteUseCase _saveNote;
  final UnsaveNoteUseCase _unsaveNote;
  final EmbedAndStoreNoteUseCase _embed;
  final WatchIsFollowedUseCase _watchIsFollowed;
  final FollowNoteUseCase _followNote;
  final UnfollowNoteUseCase _unfollowNote;
  final BlockUserUseCase _blockUser;
  final DeleteNoteUseCase _deleteNote;
  final GetActiveUserUseCase _getActiveUser;
  final NoteEntity note;

  StreamSubscription<ProfileEntity?>? _profileSub;
  StreamSubscription<bool>? _followedSub;

  NoteCardCubit(
    this._watchProfile,
    this._requestProfileFetch,
    this._isSavedUseCase,
    this._saveNote,
    this._unsaveNote,
    this._embed,
    this._watchIsFollowed,
    this._followNote,
    this._unfollowNote,
    this._blockUser,
    this._deleteNote,
    this._getActiveUser,
    @factoryParam this.note,
  ) : super(const NoteCardState()) {
    _init();
  }

  void _init() {
    _profileSub = _watchProfile.call(note.authorPubkey).listen((p) {
      if (!isClosed && p != null) emit(state.copyWith(profile: p));
    });
    // Ask the gateway to fetch the author's Kind 0 if we don't have it locally.
    _requestProfileFetch.call(note.authorPubkey);
    _followedSub = _watchIsFollowed.call(note.id).listen((followed) {
      if (!isClosed) emit(state.copyWith(isFollowed: followed));
    });
    _loadSaved();
    _loadIsOwnNote();
  }

  Future<void> _loadIsOwnNote() async {
    final r = await _getActiveUser.call();
    r.fold((_) {}, (user) {
      if (!isClosed && user.pubkeyHex == note.authorPubkey) {
        emit(state.copyWith(isOwnNote: true));
      }
    });
  }

  Future<void> _loadSaved() async {
    final r = await _isSavedUseCase.call(note.id);
    r.fold((_) {}, (v) {
      if (!isClosed) emit(state.copyWith(isSaved: v));
    });
  }

  /// Optimistic save toggle; reverts on failure. Embeds the saved note for
  /// RAG/graph on success (same flow as the feed + LargeNoteCard).
  Future<void> toggleSave() async {
    final nowSaved = !state.isSaved;
    emit(state.copyWith(isSaved: nowSaved));
    if (nowSaved) {
      final result = await _saveNote.call(note);
      result.fold(
        (_) {
          if (!isClosed) emit(state.copyWith(isSaved: false));
        },
        (saved) => _embed.call((saved.eventId, saved.content)),
      );
    } else {
      final result = await _unsaveNote.call(note.id);
      result.fold(
        (_) {
          if (!isClosed) emit(state.copyWith(isSaved: true));
        },
        (_) {},
      );
    }
  }

  /// Toggles follow state. The reactive `_watchIsFollowed` subscription drives
  /// the emitted [NoteCardState.isFollowed]; this only performs the write.
  Future<void> toggleFollow() async {
    if (state.isFollowed) {
      await _unfollowNote.call(note.id);
    } else {
      await _followNote.call(
        FollowNoteInput(
          eventId: note.id,
          contentPreview: formatContentPreview(note.content),
        ),
      );
    }
  }

  /// Blocks the note's author. Future inbound events from this pubkey are
  /// dropped by the gateway; existing notes already in Isar stay visible.
  Future<Either<Failure, Unit>> blockUser() =>
      _blockUser.call(note.authorPubkey);

  /// Deletes this note locally and tombstones it so the gateway never resyncs
  /// it. On success the card collapses itself via [NoteCardState.isRemoved].
  Future<Either<Failure, Unit>> deleteNote() async {
    final result = await _deleteNote.call(note.id);
    result.fold((_) {}, (_) {
      if (!isClosed) emit(state.copyWith(isRemoved: true));
    });
    return result;
  }

  @override
  Future<void> close() {
    _profileSub?.cancel();
    _followedSub?.cancel();
    return super.close();
  }
}
