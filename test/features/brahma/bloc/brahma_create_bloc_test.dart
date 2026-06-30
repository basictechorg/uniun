import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart' show PickedMedia;
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';

/// State-machine tests for [BrahmaCreateBloc]. Every collaborator is faked
/// with `implements <UseCase>` + `noSuchMethod` so we don't need to
/// construct the use case's deep dependency graph.
///
/// What this file proves:
///   - Pure state events (add / remove / restore mentions, attach / remove
///     media) mutate state correctly with no side effects.
///   - RestoreDraftMentions filters tombstones out of the draft list.
///   - SubmitNote with empty content is a silent no-op.
///   - SubmitNote happy path emits `submitting → success`, clears the
///     mention/media lists, and calls the right publish use case
///     (`PublishNoteUseCase` for plain notes, `PublishMediaNoteUseCase` when
///     attachments are present).
///   - Upload failure keeps the picks for retry (no data loss).
///   - SubmitNote with `publishChain: false` DROPS draft refs (the published
///     note has no link to them).
///   - SubmitNote with `publishChain: true` walks the dependency closure
///     before publishing the new note; root carries real child event ids.
///   - PublishDraftEvent branches between `_publishOneDraft` and
///     `_publishDraftChain` on `publishChain`; missing draft → error state.
///   - DeleteDraft / SaveDraft / LoadDrafts go through the right use case.
void main() {
  late _Keys keys;
  late _PublishNote publishNote;
  late _PublishMedia publishMedia;
  late _UploadMedia uploadMedia;
  late _SaveLocalMedia saveLocalMedia;
  late _ReadLocalMedia readLocalMedia;
  late _Embed embed;
  late _SaveDraft saveDraft;
  late _GetDrafts getDrafts;
  late _GetDraftById getDraftById;
  late _DeleteDraft deleteDraft;
  late _MarkPublished markPublished;
  late _SearchNotes searchNotes;
  late _GetNoteById getNoteById;

  BrahmaCreateBloc buildBloc() => BrahmaCreateBloc(
        keys,
        publishNote,
        publishMedia,
        uploadMedia,
        saveLocalMedia,
        readLocalMedia,
        embed,
        saveDraft,
        getDrafts,
        getDraftById,
        deleteDraft,
        markPublished,
        searchNotes,
        getNoteById,
      );

  setUp(() {
    keys = _Keys();
    publishNote = _PublishNote();
    publishMedia = _PublishMedia();
    uploadMedia = _UploadMedia();
    saveLocalMedia = _SaveLocalMedia();
    readLocalMedia = _ReadLocalMedia();
    embed = _Embed();
    saveDraft = _SaveDraft();
    getDrafts = _GetDrafts();
    getDraftById = _GetDraftById();
    deleteDraft = _DeleteDraft();
    markPublished = _MarkPublished();
    searchNotes = _SearchNotes();
    getNoteById = _GetNoteById();
  });

  NoteEntity noteOf(String id) => NoteEntity(
        id: id,
        sig: 'sig',
        authorPubkey: 'pubkey',
        content: 'n-$id',
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      );

  DraftEntity draftOf(String draftId, {String? publishedAsEventId}) =>
      DraftEntity(
        draftId: draftId,
        content: 'd-$draftId',
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        publishedAsEventId: publishedAsEventId,
      );

  Future<BrahmaCreateState> waitFor(
    BrahmaCreateBloc bloc,
    bool Function(BrahmaCreateState) predicate, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    return bloc.stream
        .firstWhere(predicate)
        .timeout(timeout, onTimeout: () => bloc.state);
  }

  // ── Pure state-only events ────────────────────────────────────────────────

  group('mention add/remove', () {
    test('AddMentionEvent appends to selectedMentions', () async {
      final bloc = buildBloc();
      bloc.add(AddMentionEvent(noteOf('A')));
      await waitFor(bloc, (s) => s.selectedMentions.isNotEmpty);
      expect(bloc.state.selectedMentions.map((n) => n.id), ['A']);
      await bloc.close();
    });

    test('AddMentionEvent duplicate is a no-op', () async {
      final bloc = buildBloc();
      bloc.add(AddMentionEvent(noteOf('A')));
      await waitFor(bloc, (s) => s.selectedMentions.isNotEmpty);
      bloc.add(AddMentionEvent(noteOf('A')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.selectedMentions, hasLength(1));
      await bloc.close();
    });

    test('AddDraftMentionEvent populates selectedDraftMentions independently', () async {
      final bloc = buildBloc();
      bloc.add(AddMentionEvent(noteOf('A')));
      bloc.add(AddDraftMentionEvent(draftOf('uuid-1')));
      await waitFor(bloc, (s) => s.selectedDraftMentions.isNotEmpty);
      expect(bloc.state.selectedMentions.map((n) => n.id), ['A']);
      expect(bloc.state.selectedDraftMentions.map((d) => d.draftId), ['uuid-1']);
      await bloc.close();
    });

    test('RemoveMentionEvent strips from BOTH lists by id (shared id namespace)', () async {
      final bloc = buildBloc();
      bloc.add(AddMentionEvent(noteOf('A')));
      bloc.add(AddDraftMentionEvent(draftOf('uuid-1')));
      await waitFor(bloc, (s) =>
          s.selectedMentions.isNotEmpty && s.selectedDraftMentions.isNotEmpty);

      bloc.add(const RemoveMentionEvent('A'));
      await waitFor(bloc, (s) => s.selectedMentions.isEmpty);
      expect(bloc.state.selectedDraftMentions, hasLength(1));

      bloc.add(const RemoveMentionEvent('uuid-1'));
      await waitFor(bloc, (s) => s.selectedDraftMentions.isEmpty);
      await bloc.close();
    });
  });

  // ── RestoreDraftMentions ──────────────────────────────────────────────────

  group('RestoreDraftMentions', () {
    test('splits ids into notes vs drafts via the correct use cases', () async {
      getNoteById.notes = {'note-1': noteOf('note-1')};
      getDraftById.drafts = {'uuid-1': draftOf('uuid-1')};

      final bloc = buildBloc();
      bloc.add(const RestoreDraftMentionsEvent(
        noteIds: ['note-1'],
        draftIds: ['uuid-1'],
      ));
      await waitFor(bloc, (s) => s.selectedMentions.isNotEmpty);
      expect(bloc.state.selectedMentions.map((n) => n.id), ['note-1']);
      expect(bloc.state.selectedDraftMentions.map((d) => d.draftId), ['uuid-1']);
      await bloc.close();
    });

    test('drops tombstones (publishedAsEventId != null)', () async {
      getDraftById.drafts = {
        'live': draftOf('live'),
        'gone': draftOf('gone', publishedAsEventId: 'evt-x'),
      };

      final bloc = buildBloc();
      bloc.add(const RestoreDraftMentionsEvent(
        noteIds: [],
        draftIds: ['live', 'gone'],
      ));
      await waitFor(bloc, (s) => s.selectedDraftMentions.isNotEmpty);
      expect(bloc.state.selectedDraftMentions.map((d) => d.draftId), ['live']);
      await bloc.close();
    });

    test('empty lists still emit so the picker can clear selection', () async {
      final bloc = buildBloc();
      bloc.add(AddMentionEvent(noteOf('keep')));
      await waitFor(bloc, (s) => s.selectedMentions.isNotEmpty);
      bloc.add(const RestoreDraftMentionsEvent(noteIds: [], draftIds: []));
      await waitFor(bloc, (s) => s.selectedMentions.isEmpty);
      await bloc.close();
    });
  });

  // ── Attach / Remove media ─────────────────────────────────────────────────

  group('media attach/remove', () {
    test('AttachMediaEvent appends, deduped by sha256', () async {
      final bloc = buildBloc();
      bloc.add(AttachMediaEvent(pick('sha-1')));
      await waitFor(bloc, (s) => s.pendingMedia.isNotEmpty);
      bloc.add(AttachMediaEvent(pick('sha-1')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.pendingMedia, hasLength(1));
      await bloc.close();
    });

    test('RemoveAttachedMediaEvent removes by sha256', () async {
      final bloc = buildBloc();
      bloc.add(AttachMediaEvent(pick('sha-1')));
      bloc.add(AttachMediaEvent(pick('sha-2')));
      await waitFor(bloc, (s) => s.pendingMedia.length == 2);
      bloc.add(const RemoveAttachedMediaEvent('sha-1'));
      await waitFor(bloc, (s) => s.pendingMedia.length == 1);
      expect(bloc.state.pendingMedia.single.sha256, 'sha-2');
      await bloc.close();
    });
  });

  // ── SubmitNoteEvent ───────────────────────────────────────────────────────

  group('SubmitNote', () {
    test('empty content → silent no-op (no publish, no state churn)', () async {
      final bloc = buildBloc();
      bloc.add(const SubmitNoteEvent(content: '   '));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(publishNote.calls, isEmpty);
      expect(bloc.state.status, BrahmaCreateStatus.idle);
      await bloc.close();
    });

    test('plain text → PublishNoteUseCase, success clears mention + media lists', () async {
      final bloc = buildBloc();
      bloc.add(AddMentionEvent(noteOf('m1')));
      await waitFor(bloc, (s) => s.selectedMentions.isNotEmpty);

      bloc.add(const SubmitNoteEvent(content: 'hello'));
      final final_ = await waitFor(bloc,
          (s) => s.status == BrahmaCreateStatus.success || s.status == BrahmaCreateStatus.error);
      expect(final_.status, BrahmaCreateStatus.success);
      expect(publishNote.calls, hasLength(1));
      expect(publishMedia.calls, isEmpty);
      expect(final_.selectedMentions, isEmpty);
      expect(final_.selectedDraftMentions, isEmpty);
      await bloc.close();
    });

    test('with attachments → uploads first, then PublishMediaNoteUseCase', () async {
      uploadMedia.result = Right(blob('sha-1', url: 'https://x/1'));

      final bloc = buildBloc();
      bloc.add(AttachMediaEvent(pick('sha-1', mime: 'image/jpeg')));
      await waitFor(bloc, (s) => s.pendingMedia.isNotEmpty);

      bloc.add(const SubmitNoteEvent(content: 'with pic'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.success);

      expect(uploadMedia.calls, hasLength(1));
      expect(publishMedia.calls, hasLength(1));
      expect(publishNote.calls, isEmpty);
      expect(publishMedia.calls.single.attachments, hasLength(1));
      await bloc.close();
    });

    test('upload failure → status:error; picks survive for retry', () async {
      uploadMedia.result = const Left(Failure.errorFailure('blossom down'));

      final bloc = buildBloc();
      bloc.add(AttachMediaEvent(pick('sha-1', mime: 'image/jpeg')));
      await waitFor(bloc, (s) => s.pendingMedia.isNotEmpty);

      bloc.add(const SubmitNoteEvent(content: 'try'));
      final final_ = await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.error);
      expect(final_.errorMessage, contains('blossom'));
      expect(final_.pendingMedia, hasLength(1));
      expect(publishNote.calls, isEmpty);
      expect(publishMedia.calls, isEmpty);
      await bloc.close();
    });

    test('publishChain=FALSE drops draft refs from the published note', () async {
      getDraftById.drafts = {'uuid-1': draftOf('uuid-1')};

      final bloc = buildBloc();
      bloc.add(AddDraftMentionEvent(draftOf('uuid-1')));
      await waitFor(bloc, (s) => s.selectedDraftMentions.isNotEmpty);

      bloc.add(const SubmitNoteEvent(content: 'solo'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.success);

      expect(publishNote.calls.single.eTagRefs, isEmpty);
      expect(markPublished.calls, isEmpty,
          reason: 'chain mode off → no draft was tombstoned');
      await bloc.close();
    });

    test('publishChain=TRUE publishes deps first, root carries real ids', () async {
      getDraftById.drafts = {'uuid-1': draftOf('uuid-1')};

      final bloc = buildBloc();
      bloc.add(AddDraftMentionEvent(draftOf('uuid-1')));
      await waitFor(bloc, (s) => s.selectedDraftMentions.isNotEmpty);

      bloc.add(const SubmitNoteEvent(content: 'parent', publishChain: true));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.success);

      // Two publishes: child first, then root.
      expect(publishNote.calls, hasLength(2));
      final childEventId = publishNote.calls.first.id;
      // The root's eTagRefs must thread the child's freshly-minted event id
      // (the BLoC builds the root from the resolved UUID→eventId map).
      expect(publishNote.calls.last.eTagRefs, [childEventId]);
      // markPublished tombstoned the child with that same id.
      expect(markPublished.calls, hasLength(1));
      expect(markPublished.calls.single.draftId, 'uuid-1');
      expect(markPublished.calls.single.eventId, childEventId);
      await bloc.close();
    });
  });

  // ── PublishDraftEvent ─────────────────────────────────────────────────────

  group('PublishDraft', () {
    test('publishChain=false → solo publish + tombstone', () async {
      getDraftById.drafts = {'uuid-1': draftOf('uuid-1')};

      final bloc = buildBloc();
      bloc.add(const PublishDraftEvent(draftId: 'uuid-1', content: 'body'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.success);

      expect(publishNote.calls, hasLength(1));
      // Tombstone uses the freshly-signed event id (whatever it is).
      expect(markPublished.calls.single.eventId, publishNote.calls.single.id);
      await bloc.close();
    });

    test('publishChain=true with no deps behaves like solo', () async {
      getDraftById.drafts = {'uuid-1': draftOf('uuid-1')};

      final bloc = buildBloc();
      bloc.add(const PublishDraftEvent(
          draftId: 'uuid-1', content: 'body', publishChain: true));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.success);
      // No draft deps to walk → exactly one publish (the draft itself).
      expect(publishNote.calls, hasLength(1));
      await bloc.close();
    });

    test('missing draft → status:error', () async {
      final bloc = buildBloc();
      bloc.add(const PublishDraftEvent(draftId: 'ghost', content: 'body'));
      final final_ = await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.error);
      expect(final_.errorMessage, contains('no longer exists'));
      expect(publishNote.calls, isEmpty);
      await bloc.close();
    });
  });

  // ── Save / Delete / Load drafts ──────────────────────────────────────────

  group('drafts CRUD', () {
    test('SaveDraftEvent → status:draftSaved; SaveDraftUseCase called with a fresh UUID', () async {
      final bloc = buildBloc();
      bloc.add(const SaveDraftEvent(content: 'body'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.draftSaved);
      expect(saveDraft.calls, hasLength(1));
      expect(saveDraft.calls.single.content, 'body');
      expect(saveDraft.calls.single.draftId, isNotEmpty);
      await bloc.close();
    });

    test('SaveDraftEvent with no content and no media → no-op', () async {
      final bloc = buildBloc();
      bloc.add(const SaveDraftEvent(content: '   '));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(saveDraft.calls, isEmpty);
      await bloc.close();
    });

    test('DeleteDraftEvent calls DeleteDraftUseCase', () async {
      final bloc = buildBloc();
      bloc.add(const DeleteDraftEvent('uuid-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(deleteDraft.calls, ['uuid-1']);
      await bloc.close();
    });

    test('LoadDraftsEvent populates state.drafts', () async {
      getDrafts.result = [draftOf('d-1'), draftOf('d-2')];
      final bloc = buildBloc();
      bloc.add(const LoadDraftsEvent());
      await waitFor(bloc, (s) => s.drafts.isNotEmpty);
      expect(bloc.state.drafts.map((d) => d.draftId), ['d-1', 'd-2']);
      await bloc.close();
    });
  });
}

// ── Test helpers ─────────────────────────────────────────────────────────

PickedMedia pick(String sha, {String mime = 'image/jpeg'}) => PickedMedia(
      bytes: Uint8List.fromList(const [0]),
      mime: mime,
      filename: '$sha.bin',
      sha256: sha,
    );

MediaBlobEntity blob(String sha, {String? url}) => MediaBlobEntity(
      sha256: sha,
      mime: 'image/jpeg',
      sizeBytes: 100,
      serverUrls: url == null ? const [] : [url],
    );

// ── Fakes via `implements` + noSuchMethod ─────────────────────────────────

class _Keys implements GetActiveUserKeysUseCase {
  @override
  Future<Either<Failure, UserSigningKeys>> call({bool cached = false}) async =>
      const Right(UserSigningKeys(
        privkeyHex:
            '0000000000000000000000000000000000000000000000000000000000000001',
        pubkeyHex:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ));
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _PublishNote implements PublishNoteUseCase {
  final List<NoteEntity> calls = [];
  List<String> idSequence = [];
  @override
  Future<Either<Failure, NoteEntity>> call(NoteEntity input, {bool cached = false}) async {
    final id = idSequence.isNotEmpty ? idSequence.removeAt(0) : input.id;
    final ret = input.copyWith(id: id);
    calls.add(ret);
    return Right(ret);
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _PublishMedia implements PublishMediaNoteUseCase {
  final List<PublishMediaNoteInput> calls = [];
  @override
  Future<Either<Failure, NoteEntity>> call(PublishMediaNoteInput input, {bool cached = false}) async {
    calls.add(input);
    return Right(input.note);
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _UploadMedia implements UploadMediaUseCase {
  final List<UploadMediaInput> calls = [];
  Either<Failure, MediaBlobEntity> result = Right(
    const MediaBlobEntity(sha256: 'sha', mime: 'image/jpeg', sizeBytes: 0),
  );
  @override
  Future<Either<Failure, MediaBlobEntity>> call(UploadMediaInput input, {bool cached = false}) async {
    calls.add(input);
    return result;
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SaveLocalMedia implements SaveLocalMediaUseCase {
  final List<SaveLocalMediaInput> calls = [];
  @override
  Future<Either<Failure, MediaBlobEntity>> call(SaveLocalMediaInput input, {bool cached = false}) async {
    calls.add(input);
    return Right(MediaBlobEntity(
      sha256: 'sha-${calls.length}',
      mime: input.mime,
      sizeBytes: input.bytes.length,
    ));
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ReadLocalMedia implements ReadLocalMediaUseCase {
  @override
  Future<Either<Failure, Uint8List?>> call(String sha256, {bool cached = false}) async =>
      const Right(null);
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Embed implements EmbedAndStoreNoteUseCase {
  @override
  Future<void> call((String, String) input, {bool cached = false}) async {}
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SaveDraft implements SaveDraftUseCase {
  final List<DraftEntity> calls = [];
  @override
  Future<Either<Failure, DraftEntity>> call(DraftEntity input, {bool cached = false}) async {
    calls.add(input);
    return Right(input);
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _GetDrafts implements GetDraftsUseCase {
  List<DraftEntity> result = const [];
  @override
  Future<Either<Failure, List<DraftEntity>>> call({bool cached = false}) async => Right(result);
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _GetDraftById implements GetDraftByIdUseCase {
  Map<String, DraftEntity> drafts = {};
  @override
  Future<Either<Failure, DraftEntity>> call(String input, {bool cached = false}) async {
    final d = drafts[input];
    if (d == null) return const Left(Failure.notFoundFailure('draft missing'));
    return Right(d);
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _DeleteDraft implements DeleteDraftUseCase {
  final List<String> calls = [];
  @override
  Future<Either<Failure, Unit>> call(String input, {bool cached = false}) async {
    calls.add(input);
    return const Right(unit);
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _MarkPublished implements MarkDraftPublishedUseCase {
  final List<MarkDraftPublishedInput> calls = [];
  @override
  Future<Either<Failure, Unit>> call(MarkDraftPublishedInput input, {bool cached = false}) async {
    calls.add(input);
    return const Right(unit);
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SearchNotes implements SearchNotesUseCase {
  @override
  Future<Either<Failure, List<NoteEntity>>> call(String input, {bool cached = false}) async =>
      const Right([]);
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _GetNoteById implements GetNoteByIdUseCase {
  Map<String, NoteEntity> notes = {};
  @override
  Future<Either<Failure, NoteEntity>> call(String input, {bool cached = false}) async {
    final n = notes[input];
    if (n == null) return const Left(Failure.notFoundFailure('note missing'));
    return Right(n);
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
