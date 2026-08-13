import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/profile/bloc/user_profile_bloc.dart';

import '../../../_helpers/fixtures.dart';

class _MockGetOwnNotes extends Mock implements GetOwnNotesUseCase {}

class _MockIsFollowing extends Mock implements IsFollowingUseCase {}

class _MockFollowUser extends Mock implements FollowUserUseCase {}

class _MockUnfollowUser extends Mock implements UnfollowUserUseCase {}

class _MockWatchProfile extends Mock implements WatchProfileUseCase {}

class _MockRequestProfileFetch extends Mock
    implements RequestProfileFetchUseCase {}

class _MockGetActiveUser extends Mock implements GetActiveUserUseCase {}

/// Covers: UserProfileBloc's load pipeline (isSelf detection, top-level-only
/// note filtering, the reactive watchProfile subscription re-subscribing on
/// every load, the profile-fetch nudge only when nothing is cached yet),
/// and the follow/unfollow toggle with its busy guard and failure paths.
void main() {
  late _MockGetOwnNotes getOwnNotes;
  late _MockIsFollowing isFollowing;
  late _MockFollowUser followUser;
  late _MockUnfollowUser unfollowUser;
  late _MockWatchProfile watchProfile;
  late _MockRequestProfileFetch requestProfileFetch;
  late _MockGetActiveUser getActiveUser;

  UserProfileBloc build() => UserProfileBloc(
        getOwnNotes,
        isFollowing,
        followUser,
        unfollowUser,
        watchProfile,
        requestProfileFetch,
        getActiveUser,
      );

  setUpAll(() {
    registerFallbackValue(FollowUserInput(pubkeyHex: ''));
  });

  setUp(() {
    getOwnNotes = _MockGetOwnNotes();
    isFollowing = _MockIsFollowing();
    followUser = _MockFollowUser();
    unfollowUser = _MockUnfollowUser();
    watchProfile = _MockWatchProfile();
    requestProfileFetch = _MockRequestProfileFetch();
    getActiveUser = _MockGetActiveUser();

    when(() => watchProfile.call(any())).thenAnswer((_) => const Stream.empty());
    when(() => getOwnNotes.call(any())).thenAnswer((_) async => const Right([]));
    when(() => isFollowing.call(any())).thenAnswer((_) async => const Right(false));
    when(() => requestProfileFetch.call(any())).thenAnswer((_) async => const Right(unit));
    when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'self-pub')));
  });

  group('LoadUserProfileEvent', () {
    blocTest<UserProfileBloc, UserProfileState>(
      'sets isSelf when the loaded pubkey matches the active user',
      build: build,
      act: (b) => b.add(const LoadUserProfileEvent('self-pub')),
      verify: (b) {
        expect(b.state.isSelf, isTrue);
        expect(b.state.loading, isFalse);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'isSelf is false when viewing someone else\'s profile',
      build: build,
      act: (b) => b.add(const LoadUserProfileEvent('someone-else')),
      verify: (b) {
        expect(b.state.isSelf, isFalse);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'a getActiveUser failure leaves isSelf at its default (false)',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      verify: (b) {
        expect(b.state.isSelf, isFalse);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'filters out replies, keeping only top-level notes',
      build: () {
        when(() => getOwnNotes.call('pk')).thenAnswer((_) async => Right([
              aNote(id: 'root-1'),
              aNote(id: 'reply-1', rootEventId: 'root-1'),
            ]));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      verify: (b) {
        expect(b.state.notes.map((n) => n.id), ['root-1']);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'a notes-fetch failure degrades to an empty list',
      build: () {
        when(() => getOwnNotes.call('pk'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      verify: (b) {
        expect(b.state.notes, isEmpty);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'hydrates isFollowing from IsFollowingUseCase',
      build: () {
        when(() => isFollowing.call('pk')).thenAnswer((_) async => const Right(true));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      verify: (b) {
        expect(b.state.isFollowing, isTrue);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'an isFollowing-fetch failure leaves it at the default (false)',
      build: () {
        when(() => isFollowing.call('pk'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      verify: (b) {
        expect(b.state.isFollowing, isFalse);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'nudges a profile fetch when no profile is cached yet',
      build: build,
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      verify: (_) {
        verify(() => requestProfileFetch.call('pk')).called(1);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'does not nudge a fetch once a profile update has already landed via '
      'the reactive subscription',
      build: () {
        when(() => watchProfile.call('pk')).thenAnswer((_) => Stream.value(aProfile(pubkey: 'pk')));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.profile?.pubkey, 'pk');
        verifyZeroInteractions(requestProfileFetch);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'a second load re-subscribes to watchProfile for the new pubkey '
      'instead of leaking the old subscription',
      build: build,
      act: (b) async {
        b.add(const LoadUserProfileEvent('pk-1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        b.add(const LoadUserProfileEvent('pk-2'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verify(() => watchProfile.call('pk-1')).called(1);
        verify(() => watchProfile.call('pk-2')).called(1);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'stores the hint name up front and it survives every subsequent '
      'emit through to the end of the load',
      build: () {
        // Bloc dedupes an emit() that doesn't change any field vs. the
        // immediately prior state, so give each phase a genuinely
        // different value to make its emit observable.
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(pubkeyHex: 'pk')));
        when(() => getOwnNotes.call('pk')).thenAnswer((_) async => Right([aNote(id: 'n1')]));
        when(() => isFollowing.call('pk')).thenAnswer((_) async => const Right(true));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk', hintName: 'Cached Name')),
      verify: (b) {
        expect(b.state.hintName, 'Cached Name');
        expect(b.state.isSelf, isTrue);
        expect(b.state.notes, hasLength(1));
        expect(b.state.isFollowing, isTrue);
        expect(b.state.loading, isFalse);
      },
    );
  });

  group('ProfileChangedEvent (reactive subscription)', () {
    blocTest<UserProfileBloc, UserProfileState>(
      'updates the profile in state as soon as it arrives',
      build: () {
        when(() => watchProfile.call('pk')).thenAnswer((_) => Stream.value(aProfile(pubkey: 'pk', name: 'Alice')));
        return build();
      },
      act: (b) => b.add(const LoadUserProfileEvent('pk')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.profile?.name, 'Alice');
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'a null emission (profile deleted/evicted) clears the profile too',
      build: build,
      seed: () => UserProfileState(profile: aProfile()),
      act: (b) => b.add(const ProfileChangedEvent(null)),
      expect: () => [
        isA<UserProfileState>().having((s) => s.profile, 'profile', isNull),
      ],
    );
  });

  group('ToggleFollowEvent', () {
    blocTest<UserProfileBloc, UserProfileState>(
      'follows when not currently following, using the cached profile '
      'name as the petname',
      build: () {
        when(() => followUser.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      seed: () => UserProfileState(pubkeyHex: 'pk', isFollowing: false, profile: aProfile(name: 'Alice')),
      act: (b) => b.add(const ToggleFollowEvent()),
      expect: () => [
        isA<UserProfileState>().having((s) => s.busy, 'busy', true),
        isA<UserProfileState>()
            .having((s) => s.busy, 'busy', false)
            .having((s) => s.isFollowing, 'isFollowing', true),
      ],
      verify: (_) {
        final input = verify(() => followUser.call(captureAny())).captured.single as FollowUserInput;
        expect(input.pubkeyHex, 'pk');
        expect(input.petname, 'Alice');
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'unfollows when currently following',
      build: () {
        when(() => unfollowUser.call('pk')).thenAnswer((_) async => const Right(unit));
        return build();
      },
      seed: () => const UserProfileState(pubkeyHex: 'pk', isFollowing: true),
      act: (b) => b.add(const ToggleFollowEvent()),
      expect: () => [
        isA<UserProfileState>().having((s) => s.busy, 'busy', true),
        isA<UserProfileState>()
            .having((s) => s.busy, 'busy', false)
            .having((s) => s.isFollowing, 'isFollowing', false),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'a follow failure clears busy but leaves isFollowing unchanged',
      build: () {
        when(() => followUser.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      seed: () => const UserProfileState(pubkeyHex: 'pk', isFollowing: false),
      act: (b) => b.add(const ToggleFollowEvent()),
      expect: () => [
        isA<UserProfileState>().having((s) => s.busy, 'busy', true),
        isA<UserProfileState>()
            .having((s) => s.busy, 'busy', false)
            .having((s) => s.isFollowing, 'isFollowing', false),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'an unfollow failure clears busy but leaves isFollowing unchanged',
      build: () {
        when(() => unfollowUser.call('pk'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      seed: () => const UserProfileState(pubkeyHex: 'pk', isFollowing: true),
      act: (b) => b.add(const ToggleFollowEvent()),
      expect: () => [
        isA<UserProfileState>().having((s) => s.busy, 'busy', true),
        isA<UserProfileState>()
            .having((s) => s.busy, 'busy', false)
            .having((s) => s.isFollowing, 'isFollowing', true),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'a second toggle while already busy is a no-op',
      build: build,
      seed: () => const UserProfileState(pubkeyHex: 'pk', busy: true),
      act: (b) => b.add(const ToggleFollowEvent()),
      expect: () => <UserProfileState>[],
      verify: (_) {
        verifyZeroInteractions(followUser);
        verifyZeroInteractions(unfollowUser);
      },
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'a toggle with no loaded pubkey yet is a no-op',
      build: build,
      seed: () => const UserProfileState(pubkeyHex: null),
      act: (b) => b.add(const ToggleFollowEvent()),
      expect: () => <UserProfileState>[],
      verify: (_) {
        verifyZeroInteractions(followUser);
        verifyZeroInteractions(unfollowUser);
      },
    );
  });
}
