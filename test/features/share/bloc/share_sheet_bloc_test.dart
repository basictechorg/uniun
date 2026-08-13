import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/get_groups_usecase.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/share_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/share/bloc/share_sheet_bloc.dart';

import '../../../_helpers/fixtures.dart';

class _MockGetGroups extends Mock implements GetGroupsUseCase {}

class _MockGetPrivateGroups extends Mock implements GetPrivateGroupsUsecase {}

class _MockGetDms extends Mock implements GetDmConversationsUseCase {}

class _MockShareNote extends Mock implements ShareNoteUseCase {}

class _MockUploadMedia extends Mock implements UploadMediaUseCase {}

class _MockGetActiveUser extends Mock implements GetActiveUserUseCase {}

PickedMedia _aPickedMedia({String sha256 = 'sha-1'}) => PickedMedia(
      bytes: Uint8List.fromList([1, 2, 3]),
      mime: 'image/jpeg',
      filename: 'a.jpg',
      sha256: sha256,
    );

/// Covers: ShareSheetBloc's destination-loading fan-out (groups/private
/// groups/DMs, each degrading independently to empty on failure), the
/// composer field reducers, the deferred-upload submit path (upload
/// failures abort without losing picks, success builds the ShareNoteInput
/// and reaches `submitted`), and the single-flight submit guard.
void main() {
  late _MockGetGroups getGroups;
  late _MockGetPrivateGroups getPrivateGroups;
  late _MockGetDms getDms;
  late _MockShareNote shareNote;
  late _MockUploadMedia uploadMedia;
  late _MockGetActiveUser getActiveUser;

  setUpAll(() {
    registerFallbackValue(UploadMediaInput(bytes: Uint8List(0), mime: 'image/jpeg'));
    registerFallbackValue(ShareNoteInput(source: aNote(), destination: const ShareDestination.feed()));
  });

  ShareSheetBloc build() => ShareSheetBloc(
        getGroups,
        getPrivateGroups,
        getDms,
        shareNote,
        uploadMedia,
        getActiveUser,
      );

  setUp(() {
    getGroups = _MockGetGroups();
    getPrivateGroups = _MockGetPrivateGroups();
    getDms = _MockGetDms();
    shareNote = _MockShareNote();
    uploadMedia = _MockUploadMedia();
    getActiveUser = _MockGetActiveUser();
  });

  group('LoadDestinations', () {
    blocTest<ShareSheetBloc, ShareSheetState>(
      'populates groups/private groups/DMs/author/quotedNote on success',
      build: () {
        when(() => getActiveUser()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'self-pub')));
        when(() => getGroups()).thenAnswer((_) async => Right([aGroup(groupId: 'g1')]));
        when(() => getPrivateGroups.execute())
            .thenAnswer((_) => Stream.value([aPrivateGroup(groupId: 'pg1')]));
        when(() => getDms()).thenAnswer((_) async => Right([aDmConversation(id: 1)]));
        return build();
      },
      act: (b) => b.add(ShareSheetEvent.loadDestinations(aNote(id: 'n1'))),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.loading, 'loading', true),
        isA<ShareSheetState>()
            .having((s) => s.loading, 'loading', false)
            .having((s) => s.authorPubkey, 'authorPubkey', 'self-pub')
            .having((s) => s.publicGroups, 'publicGroups', hasLength(1))
            .having((s) => s.privateGroups, 'privateGroups', hasLength(1))
            .having((s) => s.dmConversations, 'dmConversations', hasLength(1))
            .having((s) => s.quotedNote?.id, 'quotedNote.id', 'n1'),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'each destination list degrades to empty independently on its own '
      'failure — one bad source does not blank the others',
      build: () {
        when(() => getActiveUser()).thenAnswer((_) async => const Left(Failure.errorFailure('no user')));
        when(() => getGroups()).thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        when(() => getPrivateGroups.execute()).thenAnswer((_) => Stream.error(Exception('boom')));
        when(() => getDms()).thenAnswer((_) async => Right([aDmConversation(id: 1)]));
        return build();
      },
      act: (b) => b.add(ShareSheetEvent.loadDestinations(aNote())),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.loading, 'loading', true),
        isA<ShareSheetState>()
            .having((s) => s.authorPubkey, 'authorPubkey', '')
            .having((s) => s.publicGroups, 'publicGroups', isEmpty)
            .having((s) => s.privateGroups, 'privateGroups', isEmpty)
            .having((s) => s.dmConversations, 'dmConversations', hasLength(1)),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'a DM-fetch failure alone degrades dmConversations to empty',
      build: () {
        when(() => getActiveUser()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'self-pub')));
        when(() => getGroups()).thenAnswer((_) async => Right([aGroup(groupId: 'g1')]));
        when(() => getPrivateGroups.execute()).thenAnswer((_) => Stream.value(const []));
        when(() => getDms()).thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      act: (b) => b.add(ShareSheetEvent.loadDestinations(aNote())),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.loading, 'loading', true),
        isA<ShareSheetState>()
            .having((s) => s.publicGroups, 'publicGroups', hasLength(1))
            .having((s) => s.dmConversations, 'dmConversations', isEmpty),
      ],
    );
  });

  group('composer field reducers', () {
    blocTest<ShareSheetBloc, ShareSheetState>(
      'selectDestination sets selectedDestination',
      build: build,
      act: (b) => b.add(const ShareSheetEvent.selectDestination(ShareDestination.feed())),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.selectedDestination, 'selectedDestination',
            const ShareDestination.feed()),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'contentChanged updates content',
      build: build,
      act: (b) => b.add(const ShareSheetEvent.contentChanged('hello')),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.content, 'content', 'hello'),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'setReferences replaces the whole reference list',
      build: build,
      act: (b) => b.add(const ShareSheetEvent.setReferences(
        [ComposerReference(id: 'r1', label: 'Ref 1')],
      )),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.references, 'references', hasLength(1)),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'removeReference drops only the matching id',
      build: build,
      seed: () => const ShareSheetState(references: [
        ComposerReference(id: 'r1', label: 'Ref 1'),
        ComposerReference(id: 'r2', label: 'Ref 2'),
      ]),
      act: (b) => b.add(const ShareSheetEvent.removeReference('r1')),
      expect: () => [
        isA<ShareSheetState>()
            .having((s) => s.references.map((r) => r.id), 'references', ['r2']),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'attachMedia appends, ignoring a duplicate sha256',
      build: build,
      act: (b) {
        b.add(ShareSheetEvent.attachMedia(_aPickedMedia(sha256: 'a')));
        b.add(ShareSheetEvent.attachMedia(_aPickedMedia(sha256: 'a')));
        b.add(ShareSheetEvent.attachMedia(_aPickedMedia(sha256: 'b')));
      },
      expect: () => [
        // The duplicate add() is a true no-op (early `return` before any
        // emit), so only two states are emitted for three add() calls.
        isA<ShareSheetState>().having((s) => s.pending, 'pending', hasLength(1)),
        isA<ShareSheetState>().having((s) => s.pending, 'pending', hasLength(2)),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'removeMedia drops only the matching sha256',
      build: build,
      seed: () => ShareSheetState(pending: [_aPickedMedia(sha256: 'a'), _aPickedMedia(sha256: 'b')]),
      act: (b) => b.add(const ShareSheetEvent.removeMedia('a')),
      expect: () => [
        isA<ShareSheetState>()
            .having((s) => s.pending.map((m) => m.sha256), 'pending', ['b']),
      ],
    );
  });

  group('SubmitShare', () {
    blocTest<ShareSheetBloc, ShareSheetState>(
      'no pending media: shares directly with an empty attachments list',
      build: () {
        when(() => shareNote(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (b) => b.add(ShareSheetEvent.submit(
        source: aNote(id: 'n1'),
        destination: const ShareDestination.feed(),
      )),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.submitting, 'submitting', true),
        isA<ShareSheetState>()
            .having((s) => s.submitting, 'submitting', false)
            .having((s) => s.submitted, 'submitted', true),
      ],
      verify: (_) {
        verifyZeroInteractions(uploadMedia);
        final input = verify(() => shareNote(captureAny())).captured.single as ShareNoteInput;
        expect(input.source.id, 'n1');
        expect(input.attachments, isEmpty);
      },
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'uploads every pending media item before sharing, in order',
      build: () {
        when(() => uploadMedia(any())).thenAnswer((invocation) async {
          final input = invocation.positionalArguments.first as UploadMediaInput;
          return Right(MediaBlobEntity(
            sha256: input.mime, // reuse a field as a cheap per-call marker
            mime: input.mime,
            sizeBytes: input.bytes.length,
          ));
        });
        when(() => shareNote(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      seed: () => ShareSheetState(pending: [_aPickedMedia(sha256: 'a'), _aPickedMedia(sha256: 'b')]),
      act: (b) => b.add(ShareSheetEvent.submit(
        source: aNote(),
        destination: const ShareDestination.feed(),
      )),
      verify: (_) {
        verify(() => uploadMedia(any())).called(2);
        final input = verify(() => shareNote(captureAny())).captured.single as ShareNoteInput;
        expect(input.attachments, hasLength(2));
      },
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'an upload failure aborts the share, keeps the pending picks, and '
      'surfaces the error',
      build: () {
        when(() => uploadMedia(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('upload failed')));
        return build();
      },
      seed: () => ShareSheetState(pending: [_aPickedMedia()]),
      act: (b) => b.add(ShareSheetEvent.submit(
        source: aNote(),
        destination: const ShareDestination.feed(),
      )),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.submitting, 'submitting', true),
        isA<ShareSheetState>()
            .having((s) => s.submitting, 'submitting', false)
            .having((s) => s.error, 'error', isNotNull)
            .having((s) => s.pending, 'pending', hasLength(1)),
      ],
      verify: (_) {
        verifyZeroInteractions(shareNote);
      },
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'a shareNote failure surfaces the error and does not mark submitted',
      build: () {
        when(() => shareNote(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('relay down')));
        return build();
      },
      act: (b) => b.add(ShareSheetEvent.submit(
        source: aNote(),
        destination: const ShareDestination.feed(),
      )),
      expect: () => [
        isA<ShareSheetState>().having((s) => s.submitting, 'submitting', true),
        isA<ShareSheetState>()
            .having((s) => s.submitting, 'submitting', false)
            .having((s) => s.submitted, 'submitted', false)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );

    blocTest<ShareSheetBloc, ShareSheetState>(
      'a second submit while one is already in flight is a no-op',
      build: build,
      seed: () => const ShareSheetState(submitting: true),
      act: (b) => b.add(ShareSheetEvent.submit(
        source: aNote(),
        destination: const ShareDestination.feed(),
      )),
      expect: () => <ShareSheetState>[],
      verify: (_) {
        verifyZeroInteractions(shareNote);
        verifyZeroInteractions(uploadMedia);
      },
    );
  });
}
