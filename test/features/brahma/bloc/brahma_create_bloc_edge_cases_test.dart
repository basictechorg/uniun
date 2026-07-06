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

/// Edge-case + transformer + flow tests for [BrahmaCreateBloc] — the second
/// pass that covers everything the happy-path file
/// (`brahma_create_bloc_test.dart`) doesn't:
///
///   - `SearchMentionsEvent` (restartable: a late event replaces the earlier
///     result, even if the earlier one finishes after).
///   - `ClearMentionSearchEvent`, `ResetBrahmaEvent` — the small UI events.
///   - `RestoreDraftMediaEvent` — bytes re-hydrated from the cache; missing
///     bytes are silently dropped (no error state, no half-state).
///   - The `droppable` transformer on `SubmitNoteEvent` drops concurrent
///     submits while one is in flight (no duplicate publish).
///   - `SaveDraftEvent` editing path: re-saving an existing draft preserves
///     its original `createdAt` and bumps `updatedAt`.
///   - `SaveDraftEvent` with only media (no text) — accepted; not a no-op.
///   - `SaveDraftEvent` staging: each pending media goes through
///     `SaveLocalMediaUseCase` (NOT `UploadMediaUseCase` — bytes never reach
///     Blossom while it's still a draft).
///   - `PublishDraftEvent` with media: bytes are read from the cache then
///     uploaded via Blossom at publish time.
///   - `PublishDraftEvent` with media missing from the cache → status:error
///     with the "no longer available on this device" message.
///   - Mid-chain failure: `_publishDraftDependencies` returns
///     "Published N of M dependent drafts — <reason>" on partial failure.
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

  DraftEntity draftOf(
    String draftId, {
    String? publishedAsEventId,
    List<String> draftRefIds = const [],
    DateTime? createdAt,
    List<MediaBlobEntity> attachments = const [],
  }) =>
      DraftEntity(
        draftId: draftId,
        content: 'd-$draftId',
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        draftRefIds: draftRefIds,
        createdAt: createdAt ?? DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        publishedAsEventId: publishedAsEventId,
        attachments: attachments,
      );

  Future<BrahmaCreateState> waitFor(
    BrahmaCreateBloc bloc,
    bool Function(BrahmaCreateState) predicate, {
    Duration timeout = const Duration(seconds: 3),
  }) =>
      bloc.stream
          .firstWhere(predicate)
          .timeout(timeout, onTimeout: () => bloc.state);

  // ── SearchMentions ────────────────────────────────────────────────────────

  group('SearchMentions (restartable)', () {
    test('a fresh query overrides the previous results', () async {
      searchNotes.results = {
        'cats': [noteOf('cat-1'), noteOf('cat-2')],
        'dogs': [noteOf('dog-1')],
      };

      final bloc = buildBloc();
      bloc.add(const SearchMentionsEvent('cats'));
      await waitFor(bloc, (s) => s.mentionResults.isNotEmpty);
      expect(bloc.state.mentionResults.map((n) => n.id),
          ['cat-1', 'cat-2']);

      bloc.add(const SearchMentionsEvent('dogs'));
      await waitFor(
          bloc, (s) => s.mentionResults.length == 1 && !s.isMentionSearching);
      expect(bloc.state.mentionResults.map((n) => n.id), ['dog-1']);
      await bloc.close();
    });

    test('empty results leave the searching flag down', () async {
      searchNotes.results = {'nothing': []};
      final bloc = buildBloc();
      bloc.add(const SearchMentionsEvent('nothing'));
      await waitFor(bloc, (s) => s.isMentionSearching == false);
      expect(bloc.state.mentionResults, isEmpty);
      await bloc.close();
    });

    test('ClearMentionSearchEvent resets results + flag', () async {
      searchNotes.results = {'x': [noteOf('x')]};
      final bloc = buildBloc();
      bloc.add(const SearchMentionsEvent('x'));
      await waitFor(bloc, (s) => s.mentionResults.isNotEmpty);
      bloc.add(const ClearMentionSearchEvent());
      await waitFor(bloc, (s) => s.mentionResults.isEmpty);
      expect(bloc.state.isMentionSearching, isFalse);
      await bloc.close();
    });
  });

  // ── ResetBrahma ──────────────────────────────────────────────────────────

  group('ResetBrahma', () {
    test('drops every transient selection back to the initial state', () async {
      final bloc = buildBloc();
      bloc.add(AddMentionEvent(noteOf('A')));
      bloc.add(AttachMediaEvent(pick('sha-1')));
      await waitFor(bloc, (s) =>
          s.selectedMentions.isNotEmpty && s.pendingMedia.isNotEmpty);

      bloc.add(const ResetBrahmaEvent());
      await waitFor(bloc, (s) =>
          s.selectedMentions.isEmpty && s.pendingMedia.isEmpty);
      expect(bloc.state.status, BrahmaCreateStatus.idle);
      await bloc.close();
    });
  });

  // ── RestoreDraftMedia ────────────────────────────────────────────────────

  group('RestoreDraftMedia', () {
    test('present-in-cache blobs are re-hydrated into pendingMedia', () async {
      readLocalMedia.bytesBySha = {
        'sha-1': Uint8List.fromList([1, 2, 3]),
        'sha-2': Uint8List.fromList([4, 5, 6]),
      };
      final bloc = buildBloc();
      bloc.add(RestoreDraftMediaEvent([
        blob('sha-1'),
        blob('sha-2'),
      ]));
      await waitFor(bloc, (s) => s.pendingMedia.length == 2);
      expect(bloc.state.pendingMedia.map((p) => p.sha256), ['sha-1', 'sha-2']);
      await bloc.close();
    });

    test('blobs missing from cache are silently dropped (no error state)', () async {
      readLocalMedia.bytesBySha = {'sha-1': Uint8List.fromList([1])};
      final bloc = buildBloc();
      bloc.add(RestoreDraftMediaEvent([
        blob('sha-1'),
        blob('sha-missing'),
      ]));
      await waitFor(bloc, (s) => s.pendingMedia.isNotEmpty);
      expect(bloc.state.pendingMedia.map((p) => p.sha256), ['sha-1']);
      expect(bloc.state.status, isNot(BrahmaCreateStatus.error));
      await bloc.close();
    });
  });

  // ── SubmitNoteEvent droppable transformer ────────────────────────────────

  group('SubmitNote (droppable)', () {
    test('two concurrent submits → only one publish', () async {
      // Stall the publish use case so the first call hasn't returned before
      // the second event fires.
      publishNote.delay = const Duration(milliseconds: 50);

      final bloc = buildBloc();
      bloc.add(const SubmitNoteEvent(content: 'first'));
      bloc.add(const SubmitNoteEvent(content: 'second'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.success,
          timeout: const Duration(seconds: 2));
      expect(publishNote.calls, hasLength(1),
          reason: 'droppable transformer drops the second concurrent submit');
      expect(publishNote.calls.single.content, 'first');
      await bloc.close();
    });
  });

  // ── SaveDraft editing path ───────────────────────────────────────────────

  group('SaveDraft (editing)', () {
    test('re-saving an existing draft preserves the original createdAt', () async {
      final original = draftOf('uuid-1', createdAt: DateTime(2025, 1, 1));
      getDrafts.result = [original];

      final bloc = buildBloc();
      bloc.add(const LoadDraftsEvent());
      await waitFor(bloc, (s) => s.drafts.isNotEmpty);

      bloc.add(const SaveDraftEvent(
        content: 'edited body',
        draftId: 'uuid-1',
      ));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.draftSaved);

      final saved = saveDraft.calls.single;
      expect(saved.draftId, 'uuid-1');
      expect(saved.createdAt, DateTime(2025, 1, 1));
      // updatedAt is freshly stamped, so it should be after the original
      // createdAt.
      expect(saved.updatedAt.isAfter(saved.createdAt), isTrue);
      await bloc.close();
    });

    test('SaveDraft with media only (empty content) is NOT a no-op', () async {
      final bloc = buildBloc();
      bloc.add(AttachMediaEvent(pick('sha-1')));
      await waitFor(bloc, (s) => s.pendingMedia.isNotEmpty);

      bloc.add(const SaveDraftEvent(content: '   '));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.draftSaved);

      expect(saveDraft.calls, hasLength(1));
      expect(saveDraft.calls.single.attachments, hasLength(1));
      await bloc.close();
    });

    test('SaveDraft stages media LOCALLY (SaveLocalMedia, NOT UploadMedia)', () async {
      // The whole point of drafts: bytes never touch Blossom until publish.
      final bloc = buildBloc();
      bloc.add(AttachMediaEvent(pick('sha-1', mime: 'image/jpeg')));
      await waitFor(bloc, (s) => s.pendingMedia.isNotEmpty);

      bloc.add(const SaveDraftEvent(content: 'draft body'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.draftSaved);

      expect(saveLocalMedia.calls, hasLength(1));
      expect(uploadMedia.calls, isEmpty,
          reason: 'no Blossom upload while it is still a draft');
      // The saved draft carries the staged blob with no serverUrl set.
      expect(saveDraft.calls.single.attachments, hasLength(1));
      expect(saveDraft.calls.single.attachments.single.serverUrls, isEmpty);
      await bloc.close();
    });

    test('local-staging failure → status:error, picks survive', () async {
      saveLocalMedia.failNext = true;
      final bloc = buildBloc();
      bloc.add(AttachMediaEvent(pick('sha-1', mime: 'image/jpeg')));
      await waitFor(bloc, (s) => s.pendingMedia.isNotEmpty);

      bloc.add(const SaveDraftEvent(content: 'draft body'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.error);
      expect(saveDraft.calls, isEmpty);
      expect(bloc.state.pendingMedia, hasLength(1));
      await bloc.close();
    });
  });

  // ── PublishDraft with media ──────────────────────────────────────────────

  group('PublishDraft with media', () {
    test('uploads each staged blob at publish time, then publishes the note', () async {
      readLocalMedia.bytesBySha = {'sha-1': Uint8List.fromList([1])};
      uploadMedia.defaultResult =
          Right(blob('sha-1', url: 'https://blossom/sha-1'));
      getDraftById.drafts = {
        'd-1': draftOf('d-1', attachments: [blob('sha-1')]),
      };

      final bloc = buildBloc();
      bloc.add(const PublishDraftEvent(draftId: 'd-1', content: 'body'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.success);

      expect(uploadMedia.calls, hasLength(1));
      expect(publishMedia.calls, hasLength(1),
          reason: 'media-bearing publish uses PublishMediaNoteUseCase');
      expect(publishNote.calls, isEmpty);
      await bloc.close();
    });

    test('cache miss → "no longer available on this device" error, no publish', () async {
      readLocalMedia.bytesBySha = {}; // sha-1 missing
      getDraftById.drafts = {
        'd-1': draftOf('d-1', attachments: [blob('sha-1')]),
      };

      final bloc = buildBloc();
      bloc.add(const PublishDraftEvent(draftId: 'd-1', content: 'body'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.error);

      expect(bloc.state.errorMessage,
          contains('no longer available'));
      expect(uploadMedia.calls, isEmpty);
      expect(publishMedia.calls, isEmpty);
      expect(publishNote.calls, isEmpty);
      // Draft is NOT tombstoned (publish never happened).
      expect(markPublished.calls, isEmpty);
      await bloc.close();
    });

    test('mid-upload failure aborts publish; draft survives untouched', () async {
      readLocalMedia.bytesBySha = {
        'sha-1': Uint8List.fromList([1]),
        'sha-2': Uint8List.fromList([2]),
      };
      // First upload succeeds, second fails.
      uploadMedia.responseSequence = [
        Right(blob('sha-1', url: 'https://b/1')),
        const Left(Failure.errorFailure('blossom down')),
      ];
      getDraftById.drafts = {
        'd-1': draftOf('d-1',
            attachments: [blob('sha-1'), blob('sha-2')]),
      };

      final bloc = buildBloc();
      bloc.add(const PublishDraftEvent(draftId: 'd-1', content: 'body'));
      await waitFor(bloc, (s) => s.status == BrahmaCreateStatus.error);

      expect(bloc.state.errorMessage, contains('blossom'));
      expect(publishMedia.calls, isEmpty);
      expect(markPublished.calls, isEmpty);
      await bloc.close();
    });
  });

  // ── Chain publish partial failure ────────────────────────────────────────

  group('Chain publish partial failure', () {
    test('mid-chain publish failure → "Published N of M dependent drafts" error', () async {
      // Three-deep chain A → B → C. C publishes fine, B fails.
      // _publishDraftDependencies must return "Published 1 of 2 dependent
      // drafts — <reason>" before getting to A.
      getDraftById.drafts = {
        'A': draftOf('A', draftRefIds: ['B']),
        'B': draftOf('B', draftRefIds: ['C']),
        'C': draftOf('C'),
      };
      // First publish (C) succeeds, second (B) fails on the underlying
      // PublishNoteUseCase.
      publishNote.responseSequence = [
        // C succeeds — returns a successful right with C's signed event.
        null, // placeholder — actual id comes from the bloc's signing
        // B fails.
        const Left(Failure.errorFailure('relay rejected')),
      ];

      final bloc = buildBloc();
      // Drive ONLY the chain publish — no noise from other events. A's
      // draftRefIds=['B'] forces the BLoC to BFS-walk B and C before touching
      // A itself.
      bloc.add(const PublishDraftEvent(
        draftId: 'A',
        content: 'A body',
        publishChain: true,
      ));
      final final_ = await waitFor(
          bloc, (s) => s.status == BrahmaCreateStatus.error);

      expect(final_.errorMessage, contains('Published'));
      expect(final_.errorMessage, contains('dependent drafts'));
      // A itself was never attempted (chain bailed at B).
      // C was published and tombstoned; B failed before tombstoning.
      expect(markPublished.calls.map((c) => c.draftId), contains('C'));
      expect(markPublished.calls.map((c) => c.draftId), isNot(contains('B')));
      expect(markPublished.calls.map((c) => c.draftId), isNot(contains('A')));
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

// ── Fakes ────────────────────────────────────────────────────────────────

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
  Duration? delay;
  /// One entry per call. `null` → return `Right(input)` (default success).
  /// Otherwise the entry is returned verbatim (use `Left(...)` to fail).
  List<Either<Failure, NoteEntity>?> responseSequence = [];
  @override
  Future<Either<Failure, NoteEntity>> call(NoteEntity input, {bool cached = false}) async {
    if (delay != null) await Future<void>.delayed(delay!);
    calls.add(input);
    if (responseSequence.isNotEmpty) {
      final r = responseSequence.removeAt(0);
      if (r != null) return r;
    }
    return Right(input);
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
  Either<Failure, MediaBlobEntity> defaultResult =
      const Right(MediaBlobEntity(sha256: 'sha', mime: 'image/jpeg', sizeBytes: 0));
  List<Either<Failure, MediaBlobEntity>> responseSequence = [];
  @override
  Future<Either<Failure, MediaBlobEntity>> call(UploadMediaInput input, {bool cached = false}) async {
    calls.add(input);
    if (responseSequence.isNotEmpty) return responseSequence.removeAt(0);
    return defaultResult;
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SaveLocalMedia implements SaveLocalMediaUseCase {
  final List<SaveLocalMediaInput> calls = [];
  bool failNext = false;
  @override
  Future<Either<Failure, MediaBlobEntity>> call(SaveLocalMediaInput input, {bool cached = false}) async {
    calls.add(input);
    if (failNext) {
      failNext = false;
      return const Left(Failure.errorFailure('cache full'));
    }
    return Right(MediaBlobEntity(
      sha256: 'staged-${calls.length}',
      mime: input.mime,
      sizeBytes: input.bytes.length,
    ));
  }
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ReadLocalMedia implements ReadLocalMediaUseCase {
  Map<String, Uint8List> bytesBySha = {};
  @override
  Future<Either<Failure, Uint8List?>> call(String sha256, {bool cached = false}) async =>
      Right(bytesBySha[sha256]);
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
  Map<String, List<NoteEntity>> results = {};
  @override
  Future<Either<Failure, List<NoteEntity>>> call(String input, {bool cached = false}) async =>
      Right(results[input] ?? const []);
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
