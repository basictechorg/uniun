import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/private_group/private_group_join_request_entity.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/unread_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/private_groups/detail/bloc/private_group_detail_bloc.dart';

import '../../../../_helpers/fixtures.dart';

class _MockGetGroup extends Mock implements GetPrivateGroupEntityUsecase {}

class _MockGetMessages extends Mock implements GetPrivateGroupMessagesUsecase {}

class _MockGetJoinRequests extends Mock
    implements GetPrivateGroupJoinRequestsUsecase {}

class _MockSendMessage extends Mock implements SendPrivateGroupMessageUsecase {}

class _MockApproveJoin extends Mock implements ApprovePrivateGroupJoinUsecase {}

class _MockLeaveGroup extends Mock implements LeavePrivateGroupUsecase {}

class _MockGetActiveUser extends Mock implements GetActiveUserUseCase {}

class _MockGetActiveUserKeys extends Mock
    implements GetActiveUserKeysUseCase {}

class _MockGetProfile extends Mock implements GetProfileUseCase {}

class _MockMarkUnreadSeen extends Mock implements MarkUnreadSeenUseCase {}

class _MockMarkPrivateGroupSeen extends Mock
    implements MarkPrivateGroupSeenUseCase {}

PrivateGroupJoinRequestEntity _aJoinRequest({
  String eventId = 'req-1',
  String senderPubkey = 'peer-1',
  DateTime? timestamp,
}) =>
    PrivateGroupJoinRequestEntity(
      id: 0,
      eventId: eventId,
      groupId: 'g1',
      senderPubkey: senderPubkey,
      keyPackageB64: 'b64',
      timestamp: timestamp ?? DateTime(2026, 1, 1),
    );

/// Covers: PrivateGroupDetailBloc's constructor-fired load (success wiring
/// admin-gated subscriptions, missing-user / group-not-found failures),
/// message-profile hydration, join-request sender dedup, send/approve/leave
/// each with their own guard + error path, the single-mark-per-session
/// unread guard, and the isPendingApproval derived getter.
void main() {
  late _MockGetGroup getGroup;
  late _MockGetMessages getMessages;
  late _MockGetJoinRequests getJoinRequests;
  late _MockSendMessage sendMessage;
  late _MockApproveJoin approveJoin;
  late _MockLeaveGroup leaveGroup;
  late _MockGetActiveUser getActiveUser;
  late _MockGetActiveUserKeys getKeys;
  late _MockGetProfile getProfile;
  late _MockMarkUnreadSeen markUnreadSeen;
  late _MockMarkPrivateGroupSeen markGroupSeen;

  PrivateGroupDetailBloc build({String groupId = 'g1'}) => PrivateGroupDetailBloc(
        getGroup,
        getMessages,
        getJoinRequests,
        sendMessage,
        approveJoin,
        leaveGroup,
        getActiveUser,
        getKeys,
        getProfile,
        markUnreadSeen,
        markGroupSeen,
        groupId,
      );

  setUp(() {
    getGroup = _MockGetGroup();
    getMessages = _MockGetMessages();
    getJoinRequests = _MockGetJoinRequests();
    sendMessage = _MockSendMessage();
    approveJoin = _MockApproveJoin();
    leaveGroup = _MockLeaveGroup();
    getActiveUser = _MockGetActiveUser();
    getKeys = _MockGetActiveUserKeys();
    getProfile = _MockGetProfile();
    markUnreadSeen = _MockMarkUnreadSeen();
    markGroupSeen = _MockMarkPrivateGroupSeen();

    // Defaults so blocs constructed for non-load-focused tests don't hang
    // on an un-stubbed stream.
    when(() => getGroup.watch(any())).thenAnswer((_) => const Stream.empty());
    when(() => getMessages.execute(any())).thenAnswer((_) => const Stream.empty());
    when(() => getJoinRequests.execute(any())).thenAnswer((_) => const Stream.empty());
  });

  group('constructor-fired load', () {
    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'success: loads the group, marks isAdmin, and subscribes to the '
      'join-request stream only because the user IS the admin',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'admin-pub')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin-pub'));
        return build();
      },
      expect: () => [
        isA<PrivateGroupDetailState>().having((s) => s.isLoading, 'isLoading', true),
        isA<PrivateGroupDetailState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.group?.groupId, 'group.groupId', 'g1')
            .having((s) => s.isAdmin, 'isAdmin', true),
      ],
      verify: (_) {
        verify(() => getJoinRequests.execute('g1')).called(1);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a non-admin never subscribes to join requests',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'member-pub')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin-pub'));
        return build();
      },
      expect: () => [
        isA<PrivateGroupDetailState>().having((s) => s.isLoading, 'isLoading', true),
        isA<PrivateGroupDetailState>().having((s) => s.isAdmin, 'isAdmin', false),
      ],
      verify: (_) {
        verifyNever(() => getJoinRequests.execute(any()));
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a later watch() emission (the admin\'s MLS Welcome arriving) '
      'updates the group and recomputes isAdmin',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'member-pub')));
        when(() => getGroup.execute('g1')).thenAnswer(
            (_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin-pub', mlsGroupId: ''));
        when(() => getGroup.watch('g1')).thenAnswer((_) => Stream.value(
              aPrivateGroup(groupId: 'g1', adminPubkey: 'admin-pub', mlsGroupId: 'mls-1'),
            ));
        return build();
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.group?.mlsGroupId, 'mls-1');
        expect(b.state.isAdmin, isFalse);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a null watch() emission (group left/deleted) is ignored — isLeft is '
      'the only signal for that, not a null group in state',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'pk'));
        when(() => getGroup.watch('g1')).thenAnswer((_) => Stream.value(null));
        return build();
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.group, isNotNull);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'no active user surfaces as an error, never reaching getGroup',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
        return build();
      },
      expect: () => [
        isA<PrivateGroupDetailState>().having((s) => s.isLoading, 'isLoading', true),
        isA<PrivateGroupDetailState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
      verify: (_) {
        verifyZeroInteractions(getGroup);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a group that resolves to null locally surfaces as an error',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1')).thenAnswer((_) async => null);
        return build();
      },
      expect: () => [
        isA<PrivateGroupDetailState>().having((s) => s.isLoading, 'isLoading', true),
        isA<PrivateGroupDetailState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.errorMessage, 'errorMessage', contains('not found')),
      ],
    );
  });

  group('message profile hydration', () {
    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'resolves a profile for every distinct message author, caching '
      'across updates so a repeated author is not re-fetched',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'other'));
        when(() => getMessages.execute('g1')).thenAnswer((_) => Stream.fromIterable([
              [aPrivateGroupMessage(groupId: 'g1', id: 'm1', authorPubkey: 'alice')],
              [
                aPrivateGroupMessage(groupId: 'g1', id: 'm1', authorPubkey: 'alice'),
                aPrivateGroupMessage(groupId: 'g1', id: 'm2', authorPubkey: 'bob'),
              ],
            ]));
        when(() => getProfile.call('alice')).thenAnswer((_) async => Right(aProfile(pubkey: 'alice')));
        when(() => getProfile.call('bob')).thenAnswer((_) async => Right(aProfile(pubkey: 'bob')));
        return build();
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.profiles.keys, containsAll(['alice', 'bob']));
        verify(() => getProfile.call('alice')).called(1);
        verify(() => getProfile.call('bob')).called(1);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a profile lookup failure just leaves that author unresolved',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'other'));
        when(() => getMessages.execute('g1')).thenAnswer((_) => Stream.value(
              [aPrivateGroupMessage(groupId: 'g1', id: 'm1', authorPubkey: 'alice')],
            ));
        when(() => getProfile.call('alice'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('not found')));
        return build();
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.profiles, isEmpty);
        expect(b.state.messages, hasLength(1));
      },
    );
  });

  blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
    'join requests from the same sender collapse to the latest by timestamp',
    build: () {
      when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'admin-pub')));
      when(() => getGroup.execute('g1'))
          .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin-pub'));
      when(() => getJoinRequests.execute('g1')).thenAnswer((_) => Stream.value([
            _aJoinRequest(eventId: 'r1', senderPubkey: 'peer', timestamp: DateTime(2026, 1, 1)),
            _aJoinRequest(eventId: 'r2', senderPubkey: 'peer', timestamp: DateTime(2026, 1, 2)),
          ]));
      return build();
    },
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      expect(b.state.joinRequests, hasLength(1));
      expect(b.state.joinRequests.single.eventId, 'r2');
    },
  );

  group('_onSend', () {
    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'forwards content/mentions/attachments with the active user keys',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'pk'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'pk')));
        when(() => sendMessage.execute(
              groupId: any(named: 'groupId'),
              content: any(named: 'content'),
              authorPubkey: any(named: 'authorPubkey'),
              privkeyHex: any(named: 'privkeyHex'),
              mentionRefs: any(named: 'mentionRefs'),
              attachments: any(named: 'attachments'),
            )).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(SendPrivateGroupMessageEvent('hi', mentionRefs: const ['m1'])),
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verify(() => sendMessage.execute(
              groupId: 'g1',
              content: 'hi',
              authorPubkey: 'pk',
              privkeyHex: 'priv',
              mentionRefs: ['m1'],
              attachments: const [],
            )).called(1);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'no active user: silently does nothing (no error state, no send)',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'pk'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
        return build();
      },
      act: (b) => b.add(SendPrivateGroupMessageEvent('hi')),
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verifyZeroInteractions(sendMessage);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a send throw surfaces as an error message',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'pk'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'pk')));
        when(() => sendMessage.execute(
              groupId: any(named: 'groupId'),
              content: any(named: 'content'),
              authorPubkey: any(named: 'authorPubkey'),
              privkeyHex: any(named: 'privkeyHex'),
              mentionRefs: any(named: 'mentionRefs'),
              attachments: any(named: 'attachments'),
            )).thenThrow(Exception('MLS encrypt failed'));
        return build();
      },
      act: (b) => b.add(SendPrivateGroupMessageEvent('hi')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.errorMessage, contains('MLS encrypt failed'));
      },
    );
  });

  group('_onApprove', () {
    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'approves and clears isApproving on success',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'admin')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'admin')));
        when(() => approveJoin.execute(
              groupId: any(named: 'groupId'),
              userKeyPackageB64: any(named: 'userKeyPackageB64'),
              adminPrivkeyHex: any(named: 'adminPrivkeyHex'),
            )).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(ApproveJoinRequestEvent('b64')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.isApproving, isFalse);
        verify(() => approveJoin.execute(
              groupId: 'g1',
              userKeyPackageB64: 'b64',
              adminPrivkeyHex: 'priv',
            )).called(1);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'no active user: resets isApproving with no error and never calls '
      'the use case',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'admin')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
        return build();
      },
      act: (b) => b.add(ApproveJoinRequestEvent('b64')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.isApproving, isFalse);
        expect(b.state.errorMessage, isNull);
        verifyZeroInteractions(approveJoin);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a second approve while one is in flight is a no-op',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'admin')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin'));
        return build();
      },
      // seed only overrides the in-memory `state` getter used by handlers —
      // the constructor's own auto-fired LoadPrivateGroupEvent still runs
      // and emits its own two states (isLoading true, then false); this
      // test only asserts the approve-guard itself, via `verify`.
      seed: () => PrivateGroupDetailState(groupId: 'g1', isApproving: true),
      act: (b) => b.add(ApproveJoinRequestEvent('b64')),
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verifyZeroInteractions(approveJoin);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'an approve throw resets isApproving and surfaces an error',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'admin')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'admin'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'admin')));
        when(() => approveJoin.execute(
              groupId: any(named: 'groupId'),
              userKeyPackageB64: any(named: 'userKeyPackageB64'),
              adminPrivkeyHex: any(named: 'adminPrivkeyHex'),
            )).thenThrow(Exception('duplicate signature'));
        return build();
      },
      act: (b) => b.add(ApproveJoinRequestEvent('b64')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.isApproving, isFalse);
        expect(b.state.errorMessage, contains('duplicate signature'));
      },
    );
  });

  group('_onLeave', () {
    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'leaving sets isLeft on success',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'other'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'pk')));
        when(() => leaveGroup.execute(
              groupId: any(named: 'groupId'),
              authorPubkey: any(named: 'authorPubkey'),
              privkeyHex: any(named: 'privkeyHex'),
            )).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(LeavePrivateGroupEvent()),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.isLeft, isTrue);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'a leave throw surfaces an error, isLeft stays false',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'other'));
        when(() => getKeys.call())
            .thenAnswer((_) async => const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: 'pk')));
        when(() => leaveGroup.execute(
              groupId: any(named: 'groupId'),
              authorPubkey: any(named: 'authorPubkey'),
              privkeyHex: any(named: 'privkeyHex'),
            )).thenThrow(Exception('publish failed'));
        return build();
      },
      act: (b) => b.add(LeavePrivateGroupEvent()),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.isLeft, isFalse);
        expect(b.state.errorMessage, contains('publish failed'));
      },
    );
  });

  group('unread marking', () {
    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'marks an event id only once per session even if the scroll event '
      'fires again for the same id',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'other'));
        when(() => markUnreadSeen.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (b) {
        b.add(MarkPrivateGroupMessageSeenEvent('m1'));
        b.add(MarkPrivateGroupMessageSeenEvent('m1'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verify(() => markUnreadSeen.call('m1')).called(1);
      },
    );

    blocTest<PrivateGroupDetailBloc, PrivateGroupDetailState>(
      'MarkAllPrivateGroupSeenEvent delegates to markPrivateGroupSeen with '
      'the bloc\'s own groupId',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getGroup.execute('g1'))
            .thenAnswer((_) async => aPrivateGroup(groupId: 'g1', adminPubkey: 'other'));
        when(() => markGroupSeen.call('g1')).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (b) => b.add(MarkAllPrivateGroupSeenEvent()),
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verify(() => markGroupSeen.call('g1')).called(1);
      },
    );
  });

  group('isPendingApproval', () {
    test('false while loading', () {
      final s = PrivateGroupDetailState(groupId: 'g1', isLoading: true);
      expect(s.isPendingApproval, isFalse);
    });

    test('false once mlsGroupId is populated (fully joined)', () {
      final s = PrivateGroupDetailState(
        groupId: 'g1',
        group: aPrivateGroup(groupId: 'g1', mlsGroupId: 'mls-1'),
      );
      expect(s.isPendingApproval, isFalse);
    });

    test('false for the admin even with an empty mlsGroupId', () {
      final s = PrivateGroupDetailState(
        groupId: 'g1',
        group: aPrivateGroup(groupId: 'g1', mlsGroupId: ''),
        isAdmin: true,
      );
      expect(s.isPendingApproval, isFalse);
    });

    test('true for a non-admin member with an empty mlsGroupId', () {
      final s = PrivateGroupDetailState(
        groupId: 'g1',
        group: aPrivateGroup(groupId: 'g1', mlsGroupId: ''),
        isAdmin: false,
      );
      expect(s.isPendingApproval, isTrue);
    });
  });
}
