import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';
import 'package:uniun/domain/usecases/get_group_by_id_usecase.dart';
import 'package:uniun/domain/usecases/get_group_messages_usecase.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/unread_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/groups/feed/bloc/group_feed_bloc.dart';
import 'package:uniun/features/groups/feed/bloc/group_feed_event.dart';
import 'package:uniun/features/groups/feed/bloc/group_feed_state.dart';

import '../../../../_helpers/fixtures.dart';

class _MockGetGroupById extends Mock implements GetGroupByIdUseCase {}

class _MockGetOldestUnreadTime extends Mock
    implements GetGroupOldestUnreadTimeUseCase {}

class _MockGetGroupMessages extends Mock implements GetGroupMessagesUseCase {}

class _MockGetGroupMessagesAfter extends Mock
    implements GetGroupMessagesAfterUseCase {}

class _MockGetActiveUserKeys extends Mock
    implements GetActiveUserKeysUseCase {}

class _MockCreateGroupMessage extends Mock
    implements CreateGroupMessageUseCase {}

class _MockSaveNote extends Mock implements SaveNoteUseCase {}

class _MockUnsaveNote extends Mock implements UnsaveNoteUseCase {}

class _MockGetProfile extends Mock implements GetProfileUseCase {}

class _MockIsSavedNote extends Mock implements IsSavedNoteUseCase {}

class _MockMarkUnreadSeen extends Mock implements MarkUnreadSeenUseCase {}

class _MockMarkGroupSeen extends Mock implements MarkGroupSeenUseCase {}

/// Covers: GroupFeedBloc's bidirectional initial load (read/unread boundary
/// split, group-not-found error), older/newer pagination with their guards
/// and dedup-against-existing-ids, send's empty-input guard + success +
/// failure, optimistic save/unsave, profile/saved-id hydration + merge on
/// pagination, and the once-per-session mark-seen guard. Every use case is
/// resolved via get_it (this bloc has no constructor injection), following
/// this repo's established get_it-reset test pattern.
void main() {
  late _MockGetGroupById getGroupById;
  late _MockGetOldestUnreadTime getOldestUnreadTime;
  late _MockGetGroupMessages getGroupMessages;
  late _MockGetGroupMessagesAfter getGroupMessagesAfter;
  late _MockGetActiveUserKeys getActiveUserKeys;
  late _MockCreateGroupMessage createGroupMessage;
  late _MockSaveNote saveNote;
  late _MockUnsaveNote unsaveNote;
  late _MockGetProfile getProfile;
  late _MockIsSavedNote isSavedNote;
  late _MockMarkUnreadSeen markUnreadSeen;
  late _MockMarkGroupSeen markGroupSeen;
  late GetIt getIt;

  setUpAll(() {
    registerFallbackValue(const CreateGroupMessageInput(groupId: '', content: '', privateKey: ''));
    registerFallbackValue(aNote());
    registerFallbackValue(const GetGroupMessagesInput(groupId: ''));
    registerFallbackValue(GetGroupMessagesAfterInput(groupId: '', after: DateTime(2026, 1, 1)));
  });

  setUp(() async {
    getIt = GetIt.instance;
    await getIt.reset();
    getGroupById = _MockGetGroupById();
    getOldestUnreadTime = _MockGetOldestUnreadTime();
    getGroupMessages = _MockGetGroupMessages();
    getGroupMessagesAfter = _MockGetGroupMessagesAfter();
    getActiveUserKeys = _MockGetActiveUserKeys();
    createGroupMessage = _MockCreateGroupMessage();
    saveNote = _MockSaveNote();
    unsaveNote = _MockUnsaveNote();
    getProfile = _MockGetProfile();
    isSavedNote = _MockIsSavedNote();
    markUnreadSeen = _MockMarkUnreadSeen();
    markGroupSeen = _MockMarkGroupSeen();

    getIt.registerFactory<GetGroupByIdUseCase>(() => getGroupById);
    getIt.registerFactory<GetGroupOldestUnreadTimeUseCase>(() => getOldestUnreadTime);
    getIt.registerFactory<GetGroupMessagesUseCase>(() => getGroupMessages);
    getIt.registerFactory<GetGroupMessagesAfterUseCase>(() => getGroupMessagesAfter);
    getIt.registerFactory<GetActiveUserKeysUseCase>(() => getActiveUserKeys);
    getIt.registerFactory<CreateGroupMessageUseCase>(() => createGroupMessage);
    getIt.registerFactory<SaveNoteUseCase>(() => saveNote);
    getIt.registerFactory<UnsaveNoteUseCase>(() => unsaveNote);
    getIt.registerFactory<GetProfileUseCase>(() => getProfile);
    getIt.registerFactory<IsSavedNoteUseCase>(() => isSavedNote);
    getIt.registerFactory<MarkUnreadSeenUseCase>(() => markUnreadSeen);
    getIt.registerFactory<MarkGroupSeenUseCase>(() => markGroupSeen);

    when(() => getGroupMessages.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getGroupMessagesAfter.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getProfile.call(any()))
        .thenAnswer((_) async => const Left(Failure.errorFailure('not found')));
    when(() => isSavedNote.call(any())).thenAnswer((_) async => const Right(false));
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('LoadGroupFeedEvent', () {
    blocTest<GroupFeedBloc, GroupFeedState>(
      'group not found surfaces an error',
      build: () {
        when(() => getGroupById.call('g1'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('not found')));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const LoadGroupFeedEvent('g1')),
      expect: () => [
        isA<GroupFeedState>().having((s) => s.status, 'status', GroupFeedStatus.loading),
        isA<GroupFeedState>().having((s) => s.status, 'status', GroupFeedStatus.error),
      ],
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'silent:true suppresses the loading state',
      build: () {
        when(() => getGroupById.call('g1'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('not found')));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const LoadGroupFeedEvent('g1', silent: true)),
      expect: () => [
        isA<GroupFeedState>().having((s) => s.status, 'status', GroupFeedStatus.error),
      ],
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'no unread boundary: opens at the bottom with only the top (read) page',
      build: () {
        when(() => getGroupById.call('g1')).thenAnswer((_) async => Right(aGroup(groupId: 'g1')));
        when(() => getOldestUnreadTime.call('g1')).thenAnswer((_) async => const Right(null));
        when(() => getGroupMessages.call(any()))
            .thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1', id: 'm2'), aGroupMessage(groupId: 'g1', id: 'm1')]));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const LoadGroupFeedEvent('g1')),
      verify: (b) {
        expect(b.state.status, GroupFeedStatus.loaded);
        // topRaw is newest-first ([m2, m1]); reversed to ascending [m1, m2].
        expect(b.state.messages.map((m) => m.id), ['m1', 'm2']);
        expect(b.state.openedAtMiddle, isFalse);
        expect(b.state.boundaryIndex, 2);
        verifyZeroInteractions(getGroupMessagesAfter);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'with an unread boundary: combines the top (read) and bottom (unread) '
      'sections and anchors at the middle',
      build: () {
        final boundary = DateTime(2026, 1, 1);
        when(() => getGroupById.call('g1')).thenAnswer((_) async => Right(aGroup(groupId: 'g1')));
        when(() => getOldestUnreadTime.call('g1')).thenAnswer((_) async => Right(boundary));
        when(() => getGroupMessages.call(any())).thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1', id: 'read-1')]));
        when(() => getGroupMessagesAfter.call(any())).thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1', id: 'unread-1')]));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const LoadGroupFeedEvent('g1')),
      verify: (b) {
        expect(b.state.messages.map((m) => m.id), ['read-1', 'unread-1']);
        expect(b.state.openedAtMiddle, isTrue);
        expect(b.state.boundaryIndex, 1);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'hasMoreOlder/hasMoreUnread are true only when a full page came back',
      build: () {
        when(() => getGroupById.call('g1')).thenAnswer((_) async => Right(aGroup(groupId: 'g1')));
        when(() => getOldestUnreadTime.call('g1')).thenAnswer((_) async => Right(DateTime(2026, 1, 1)));
        when(() => getGroupMessages.call(any())).thenAnswer(
            (_) async => Right(List.generate(10, (i) => aGroupMessage(groupId: 'g1', id: 'r$i'))));
        when(() => getGroupMessagesAfter.call(any())).thenAnswer(
            (_) async => Right(List.generate(10, (i) => aGroupMessage(groupId: 'g1', id: 'u$i'))));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const LoadGroupFeedEvent('g1')),
      verify: (b) {
        expect(b.state.hasMoreOlder, isTrue);
        expect(b.state.hasMoreUnread, isTrue);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'hydrates a profile per distinct author and the saved-ids set',
      build: () {
        when(() => getGroupById.call('g1')).thenAnswer((_) async => Right(aGroup(groupId: 'g1')));
        when(() => getOldestUnreadTime.call('g1')).thenAnswer((_) async => const Right(null));
        when(() => getGroupMessages.call(any())).thenAnswer(
            (_) async => Right([aGroupMessage(groupId: 'g1', id: 'm1', authorPubkey: 'alice')]));
        when(() => getProfile.call('alice')).thenAnswer((_) async => Right(aProfile(pubkey: 'alice')));
        when(() => isSavedNote.call('m1')).thenAnswer((_) async => const Right(true));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const LoadGroupFeedEvent('g1')),
      verify: (b) {
        expect(b.state.profiles.keys, contains('alice'));
        expect(b.state.savedIds, {'m1'});
      },
    );
  });

  group('LoadOlderGroupMessagesEvent', () {
    blocTest<GroupFeedBloc, GroupFeedState>(
      'a no-op while already loading older, no more older, or no messages '
      'loaded yet',
      build: () => GroupFeedBloc(),
      seed: () => const GroupFeedState(hasMoreOlder: true, messages: []),
      act: (b) => b.add(const LoadOlderGroupMessagesEvent('g1')),
      expect: () => <GroupFeedState>[],
      verify: (_) {
        verifyZeroInteractions(getGroupMessages);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'prepends fresh older messages ascending, deduping against what is '
      'already loaded',
      build: () {
        when(() => getGroupMessages.call(any())).thenAnswer(
            (_) async => Right([aGroupMessage(groupId: 'g1', id: 'existing'), aGroupMessage(groupId: 'g1', id: 'new-1')]));
        return GroupFeedBloc();
      },
      seed: () => GroupFeedState(
        hasMoreOlder: true,
        messages: [aGroupMessage(groupId: 'g1', id: 'existing')],
        boundaryIndex: 1,
      ),
      act: (b) => b.add(const LoadOlderGroupMessagesEvent('g1')),
      verify: (b) {
        expect(b.state.messages.map((m) => m.id), ['new-1', 'existing']);
        expect(b.state.boundaryIndex, 2);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'no fresh messages beyond what is loaded sets hasMoreOlder=false',
      build: () {
        when(() => getGroupMessages.call(any()))
            .thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1', id: 'existing')]));
        return GroupFeedBloc();
      },
      seed: () => GroupFeedState(
        hasMoreOlder: true,
        messages: [aGroupMessage(groupId: 'g1', id: 'existing')],
      ),
      act: (b) => b.add(const LoadOlderGroupMessagesEvent('g1')),
      verify: (b) {
        expect(b.state.hasMoreOlder, isFalse);
        expect(b.state.isLoadingOlder, isFalse);
      },
    );
  });

  group('LoadNewerGroupMessagesEvent', () {
    blocTest<GroupFeedBloc, GroupFeedState>(
      'a no-op with no messages loaded',
      build: () => GroupFeedBloc(),
      act: (b) => b.add(const LoadNewerGroupMessagesEvent('g1')),
      expect: () => <GroupFeedState>[],
      verify: (_) {
        verifyZeroInteractions(getGroupMessagesAfter);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'hasMoreUnread=false blocks a normal call but isRefresh bypasses it',
      build: () {
        when(() => getGroupMessagesAfter.call(any()))
            .thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1', id: 'fresh')]));
        return GroupFeedBloc();
      },
      seed: () => GroupFeedState(hasMoreUnread: false, messages: [aGroupMessage(groupId: 'g1', id: 'existing')]),
      act: (b) => b.add(const LoadNewerGroupMessagesEvent('g1', isRefresh: true)),
      verify: (b) {
        expect(b.state.messages.map((m) => m.id), ['existing', 'fresh']);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'appends fresh newer messages, deduping against what is loaded',
      build: () {
        when(() => getGroupMessagesAfter.call(any())).thenAnswer(
            (_) async => Right([aGroupMessage(groupId: 'g1', id: 'existing'), aGroupMessage(groupId: 'g1', id: 'new-1')]));
        return GroupFeedBloc();
      },
      seed: () => GroupFeedState(hasMoreUnread: true, messages: [aGroupMessage(groupId: 'g1', id: 'existing')]),
      act: (b) => b.add(const LoadNewerGroupMessagesEvent('g1')),
      verify: (b) {
        expect(b.state.messages.map((m) => m.id), ['existing', 'new-1']);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'no fresh newer messages beyond what is loaded sets hasMoreUnread=false',
      build: () {
        when(() => getGroupMessagesAfter.call(any()))
            .thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1', id: 'existing')]));
        return GroupFeedBloc();
      },
      seed: () => GroupFeedState(hasMoreUnread: true, messages: [aGroupMessage(groupId: 'g1', id: 'existing')]),
      act: (b) => b.add(const LoadNewerGroupMessagesEvent('g1')),
      verify: (b) {
        expect(b.state.hasMoreUnread, isFalse);
        expect(b.state.isLoadingUnread, isFalse);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'a newly-paginated message that is already saved is folded into '
      'savedIds via _mergeSaved',
      build: () {
        when(() => getGroupMessagesAfter.call(any()))
            .thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1', id: 'existing'), aGroupMessage(groupId: 'g1', id: 'new-saved')]));
        when(() => isSavedNote.call('new-saved')).thenAnswer((_) async => const Right(true));
        return GroupFeedBloc();
      },
      seed: () => GroupFeedState(hasMoreUnread: true, messages: [aGroupMessage(groupId: 'g1', id: 'existing')]),
      act: (b) => b.add(const LoadNewerGroupMessagesEvent('g1')),
      verify: (b) {
        expect(b.state.savedIds, contains('new-saved'));
      },
    );
  });

  group('SendGroupMessageEvent', () {
    blocTest<GroupFeedBloc, GroupFeedState>(
      'empty content and no attachments is a no-op',
      build: () => GroupFeedBloc(),
      act: (b) => b.add(const SendGroupMessageEvent(groupId: 'g1', content: '   ')),
      expect: () => <GroupFeedState>[],
      verify: (_) {
        verifyZeroInteractions(createGroupMessage);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'no active user keys surfaces an error',
      build: () {
        when(() => getActiveUserKeys.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const SendGroupMessageEvent(groupId: 'g1', content: 'hi')),
      verify: (b) {
        expect(b.state.isSending, isFalse);
        expect(b.state.errorMessage, isNotNull);
        verifyZeroInteractions(createGroupMessage);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'success appends the sent message without a full reload',
      build: () {
        when(() => getActiveUserKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'pk')));
        when(() => createGroupMessage.call(any()))
            .thenAnswer((_) async => Right(aGroupMessage(groupId: 'g1', id: 'sent-1')));
        return GroupFeedBloc();
      },
      seed: () => GroupFeedState(messages: [aGroupMessage(groupId: 'g1', id: 'm1')]),
      act: (b) => b.add(const SendGroupMessageEvent(groupId: 'g1', content: 'hi')),
      verify: (b) {
        expect(b.state.isSending, isFalse);
        expect(b.state.messages.map((m) => m.id), ['m1', 'sent-1']);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'a send failure surfaces an error',
      build: () {
        when(() => getActiveUserKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'pk')));
        when(() => createGroupMessage.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('relay down')));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const SendGroupMessageEvent(groupId: 'g1', content: 'hi')),
      verify: (b) {
        expect(b.state.isSending, isFalse);
        expect(b.state.errorMessage, isNotNull);
      },
    );
  });

  group('save / unsave', () {
    blocTest<GroupFeedBloc, GroupFeedState>(
      'save adds the id to savedIds on success, no-ops on failure',
      build: () {
        when(() => saveNote.call(any())).thenAnswer((_) async => Right(aSavedNote(eventId: 'm1')));
        return GroupFeedBloc();
      },
      act: (b) => b.add(SaveGroupFeedMessageEvent(aGroupMessage(groupId: 'g1', id: 'm1'))),
      expect: () => [
        isA<GroupFeedState>().having((s) => s.savedIds, 'savedIds', {'m1'}),
      ],
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'a save failure does not add the id',
      build: () {
        when(() => saveNote.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return GroupFeedBloc();
      },
      act: (b) => b.add(SaveGroupFeedMessageEvent(aGroupMessage(groupId: 'g1', id: 'm1'))),
      expect: () => <GroupFeedState>[],
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'unsave removes the id from savedIds on success',
      build: () {
        when(() => unsaveNote.call('m1')).thenAnswer((_) async => const Right(unit));
        return GroupFeedBloc();
      },
      seed: () => const GroupFeedState(savedIds: {'m1'}),
      act: (b) => b.add(const UnsaveGroupFeedMessageEvent('m1')),
      expect: () => [
        isA<GroupFeedState>().having((s) => s.savedIds, 'savedIds', isEmpty),
      ],
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'an unsave failure leaves savedIds unchanged',
      build: () {
        when(() => unsaveNote.call('m1'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return GroupFeedBloc();
      },
      seed: () => const GroupFeedState(savedIds: {'m1'}),
      act: (b) => b.add(const UnsaveGroupFeedMessageEvent('m1')),
      expect: () => <GroupFeedState>[],
    );
  });

  group('mark seen', () {
    blocTest<GroupFeedBloc, GroupFeedState>(
      'marks an event id once per session',
      build: () {
        when(() => markUnreadSeen.call(any())).thenAnswer((_) async => const Right(unit));
        return GroupFeedBloc();
      },
      act: (b) {
        b.add(const MarkGroupMessageSeenEvent('n1'));
        b.add(const MarkGroupMessageSeenEvent('n1'));
      },
      verify: (_) {
        verify(() => markUnreadSeen.call('n1')).called(1);
      },
    );

    blocTest<GroupFeedBloc, GroupFeedState>(
      'MarkAllGroupSeenEvent delegates with the event groupId',
      build: () {
        when(() => markGroupSeen.call('g1')).thenAnswer((_) async => const Right(unit));
        return GroupFeedBloc();
      },
      act: (b) => b.add(const MarkAllGroupSeenEvent('g1')),
      verify: (_) {
        verify(() => markGroupSeen.call('g1')).called(1);
      },
    );
  });
}
