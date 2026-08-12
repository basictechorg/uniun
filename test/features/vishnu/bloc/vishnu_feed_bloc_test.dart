import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';
import 'package:uniun/domain/usecases/feed_usecases.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/vishnu/bloc/vishnu_feed_bloc.dart';

import '../../../_helpers/fixtures.dart';

class _MockGetOrInitLoadedAt extends Mock implements GetOrInitFeedLoadedAtUseCase {}

class _MockSetLoadedAt extends Mock implements SetFeedLoadedAtUseCase {}

class _MockGetUnreadPage extends Mock implements GetUnreadPageUseCase {}

class _MockGetSeenPage extends Mock implements GetSeenPageUseCase {}

class _MockWatchNewCount extends Mock implements WatchNewBufferCountUseCase {}

class _MockMarkSeen extends Mock implements MarkFeedItemSeenUseCase {}

class _MockGetProfile extends Mock implements GetProfileUseCase {}

class _MockGetAllSaved extends Mock implements GetAllSavedNotesUseCase {}

class _MockSaveNote extends Mock implements SaveNoteUseCase {}

class _MockUnsaveNote extends Mock implements UnsaveNoteUseCase {}

class _MockEmbedAndStore extends Mock implements EmbedAndStoreNoteUseCase {}

class _MockWatchFollowed extends Mock implements WatchFollowedUsersUseCase {}

/// Covers: VishnuFeedBloc's open/anchor-load, the unread-then-seen page
/// pagination with cross-page dedup, error surfacing from either phase,
/// exhaustion detection, load-more's guards, the banner reload (load-new /
/// refresh), the followed-users watcher's "skip the first emission, reload
/// only on an actual count change" debounce, profile hydration/caching,
/// saved-ids loading, mark-seen's once-per-session guard, and optimistic
/// save/unsave with rollback on failure.
void main() {
  late _MockGetOrInitLoadedAt getOrInitLoadedAt;
  late _MockSetLoadedAt setLoadedAt;
  late _MockGetUnreadPage getUnreadPage;
  late _MockGetSeenPage getSeenPage;
  late _MockWatchNewCount watchNewCount;
  late _MockMarkSeen markSeen;
  late _MockGetProfile getProfile;
  late _MockGetAllSaved getAllSaved;
  late _MockSaveNote saveNote;
  late _MockUnsaveNote unsaveNote;
  late _MockEmbedAndStore embedAndStore;
  late _MockWatchFollowed watchFollowed;

  final loadedAt = DateTime(2026, 1, 1);

  VishnuFeedBloc build() => VishnuFeedBloc(
        getOrInitLoadedAt,
        setLoadedAt,
        getUnreadPage,
        getSeenPage,
        watchNewCount,
        markSeen,
        getProfile,
        getAllSaved,
        saveNote,
        unsaveNote,
        embedAndStore,
        watchFollowed,
      );

  setUpAll(() {
    registerFallbackValue(const UnreadPageInput(limit: 0, excludeIds: {}));
    registerFallbackValue(const SeenPageInput(limit: 0));
    registerFallbackValue(aNote());
    registerFallbackValue(('', ''));
  });

  setUp(() {
    getOrInitLoadedAt = _MockGetOrInitLoadedAt();
    setLoadedAt = _MockSetLoadedAt();
    getUnreadPage = _MockGetUnreadPage();
    getSeenPage = _MockGetSeenPage();
    watchNewCount = _MockWatchNewCount();
    markSeen = _MockMarkSeen();
    getProfile = _MockGetProfile();
    getAllSaved = _MockGetAllSaved();
    saveNote = _MockSaveNote();
    unsaveNote = _MockUnsaveNote();
    embedAndStore = _MockEmbedAndStore();
    watchFollowed = _MockWatchFollowed();

    when(() => getOrInitLoadedAt.call()).thenAnswer((_) async => Right(loadedAt));
    when(() => watchNewCount.call(any())).thenAnswer((_) => const Stream.empty());
    when(() => watchFollowed.call(any())).thenAnswer((_) => const Stream.empty());
    when(() => getUnreadPage.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getSeenPage.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getAllSaved.call()).thenAnswer((_) async => const Right([]));
    when(() => getProfile.call(any()))
        .thenAnswer((_) async => const Left(Failure.errorFailure('not stubbed')));
  });

  group('FeedOpenedEvent', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'loads the anchor, then the first page, ending exhausted when both '
      'phases are dry',
      build: build,
      act: (b) => b.add(const FeedOpenedEvent()),
      expect: () => [
        isA<VishnuFeedState>().having((s) => s.status, 'status', VishnuFeedStatus.loading),
        isA<VishnuFeedState>().having((s) => s.loadedAt, 'loadedAt', loadedAt),
        isA<VishnuFeedState>().having((s) => s.items, 'items', isEmpty), // reset before fetch
        isA<VishnuFeedState>()
            .having((s) => s.status, 'status', VishnuFeedStatus.loaded)
            .having((s) => s.exhausted, 'exhausted', true)
            .having((s) => s.items, 'items', isEmpty),
      ],
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'a second open while already initial-loading is a no-op (guarded by '
      'status != initial)',
      build: build,
      seed: () => const VishnuFeedState(status: VishnuFeedStatus.loading),
      act: (b) => b.add(const FeedOpenedEvent()),
      expect: () => <VishnuFeedState>[],
      verify: (_) {
        verifyZeroInteractions(getOrInitLoadedAt);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'a loadedAt-fetch failure falls back to DateTime.now() rather than '
      'blocking the page load',
      build: () {
        when(() => getOrInitLoadedAt.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      verify: (b) {
        expect(b.state.loadedAt, isNotNull);
        expect(b.state.status, VishnuFeedStatus.loaded);
      },
    );
  });

  group('pagination', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'unread phase fills the page first; seen phase only tops up the '
      'remaining slots',
      build: () {
        final unread = List.generate(5, (i) => aNote(id: 'u$i'));
        final seen = List.generate(3, (i) => aNote(id: 's$i'));
        when(() => getUnreadPage.call(any())).thenAnswer((_) async => Right(unread));
        when(() => getSeenPage.call(any())).thenAnswer((_) async => Right(seen));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      verify: (b) {
        expect(b.state.items, hasLength(8));
        expect(b.state.items.map((n) => n.id), ['u0', 'u1', 'u2', 'u3', 'u4', 's0', 's1', 's2']);
        expect(b.state.exhausted, isFalse);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'a duplicate id from the seen phase (already surfaced as unread) is '
      'not double-counted',
      build: () {
        when(() => getUnreadPage.call(any())).thenAnswer((_) async => Right([aNote(id: 'n1')]));
        when(() => getSeenPage.call(any())).thenAnswer((_) async => Right([aNote(id: 'n1'), aNote(id: 'n2')]));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      verify: (b) {
        expect(b.state.items.map((n) => n.id), ['n1', 'n2']);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'an unread-phase failure surfaces an error but still lets the seen '
      'phase fill the page',
      build: () {
        when(() => getUnreadPage.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('unread query failed')));
        when(() => getSeenPage.call(any())).thenAnswer((_) async => Right([aNote(id: 'n1')]));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      expect: () => [
        isA<VishnuFeedState>(),
        isA<VishnuFeedState>(),
        isA<VishnuFeedState>(),
        isA<VishnuFeedState>().having((s) => s.status, 'status', VishnuFeedStatus.error),
        isA<VishnuFeedState>()
            .having((s) => s.status, 'status', VishnuFeedStatus.loaded)
            .having((s) => s.items, 'items', hasLength(1)),
      ],
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'a seen-phase failure (reached only when unread underfills the page) '
      'surfaces its own intermediate error state — the final page-loaded '
      'emit then clears it back to null, same as the unread-phase case',
      build: () {
        when(() => getUnreadPage.call(any())).thenAnswer((_) async => const Right([]));
        when(() => getSeenPage.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('seen query failed')));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      expect: () => [
        isA<VishnuFeedState>(),
        isA<VishnuFeedState>(),
        isA<VishnuFeedState>(),
        isA<VishnuFeedState>()
            .having((s) => s.status, 'status', VishnuFeedStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        isA<VishnuFeedState>()
            .having((s) => s.status, 'status', VishnuFeedStatus.loaded)
            .having((s) => s.items, 'items', isEmpty),
      ],
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'LoadMoreFeedEvent is a no-op while exhausted, with no items yet, or '
      'without a loaded anchor',
      build: build,
      seed: () => const VishnuFeedState(exhausted: true, loadedAt: null, items: []),
      act: (b) => b.add(const LoadMoreFeedEvent()),
      expect: () => <VishnuFeedState>[],
      verify: (_) {
        verifyZeroInteractions(getUnreadPage);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'LoadMoreFeedEvent fetches another page, advancing the seen cursor',
      build: () {
        when(() => getUnreadPage.call(any())).thenAnswer((_) async => const Right([]));
        when(() => getSeenPage.call(any())).thenAnswer(
            (_) async => Right([aNote(id: 'n2', created: DateTime(2026, 1, 2))]));
        return build();
      },
      seed: () => VishnuFeedState(
        status: VishnuFeedStatus.loaded,
        items: [aNote(id: 'n1')],
        loadedAt: loadedAt,
      ),
      act: (b) => b.add(const LoadMoreFeedEvent()),
      verify: (b) {
        expect(b.state.items.map((n) => n.id), ['n1', 'n2']);
        expect(b.state.seenCursor, DateTime(2026, 1, 2));
      },
    );
  });

  group('profile hydration + saved ids', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'resolves a profile per distinct author and caches across pages',
      build: () {
        when(() => getUnreadPage.call(any())).thenAnswer(
            (_) async => Right([aNote(id: 'n1', authorPubkey: 'alice'), aNote(id: 'n2', authorPubkey: 'bob')]));
        when(() => getProfile.call('alice')).thenAnswer((_) async => Right(aProfile(pubkey: 'alice')));
        when(() => getProfile.call('bob')).thenAnswer((_) async => Right(aProfile(pubkey: 'bob')));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      verify: (b) {
        expect(b.state.profiles.keys, containsAll(['alice', 'bob']));
        verify(() => getProfile.call('alice')).called(1);
        verify(() => getProfile.call('bob')).called(1);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'loads saved ids from GetAllSavedNotesUseCase',
      build: () {
        when(() => getAllSaved.call()).thenAnswer((_) async => Right([aSavedNote(eventId: 'n1')]));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      verify: (b) {
        expect(b.state.savedIds, {'n1'});
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'a saved-ids fetch failure keeps the previous savedIds unchanged',
      build: () {
        when(() => getAllSaved.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      seed: () => const VishnuFeedState(savedIds: {'kept'}),
      act: (b) => b.add(const FeedOpenedEvent()),
      verify: (b) {
        expect(b.state.savedIds, {'kept'});
      },
    );
  });

  group('mark seen', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'marks an id once per session even if fired again for the same id',
      build: () {
        when(() => markSeen.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (b) {
        b.add(const MarkFeedItemSeenEvent('n1'));
        b.add(const MarkFeedItemSeenEvent('n1'));
      },
      verify: (_) {
        verify(() => markSeen.call('n1')).called(1);
      },
    );
  });

  group('save / unsave', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'save is optimistic and fires knowledge embedding on success',
      build: () {
        when(() => saveNote.call(any())).thenAnswer((_) async => Right(aSavedNote(eventId: 'n1')));
        when(() => embedAndStore.call(any())).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(SaveFeedNoteEvent(aNote(id: 'n1'))),
      expect: () => [
        isA<VishnuFeedState>().having((s) => s.savedIds, 'savedIds', {'n1'}),
      ],
      verify: (_) async {
        await Future<void>.delayed(Duration.zero);
        verify(() => embedAndStore.call(any())).called(1);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'a save failure rolls back the optimistic id',
      build: () {
        when(() => saveNote.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('isar write failed')));
        return build();
      },
      act: (b) => b.add(SaveFeedNoteEvent(aNote(id: 'n1'))),
      expect: () => [
        isA<VishnuFeedState>().having((s) => s.savedIds, 'savedIds', {'n1'}),
        isA<VishnuFeedState>().having((s) => s.savedIds, 'savedIds', isEmpty),
      ],
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'unsave is optimistic; a failure re-adds the id',
      build: () {
        when(() => unsaveNote.call('n1'))
            .thenAnswer((_) async => const Left(Failure.errorFailure('isar write failed')));
        return build();
      },
      seed: () => const VishnuFeedState(savedIds: {'n1'}),
      act: (b) => b.add(const UnsaveFeedNoteEvent('n1')),
      expect: () => [
        isA<VishnuFeedState>().having((s) => s.savedIds, 'savedIds', isEmpty),
        isA<VishnuFeedState>().having((s) => s.savedIds, 'savedIds', {'n1'}),
      ],
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'unsave keeps the optimistic removal on success',
      build: () {
        when(() => unsaveNote.call('n1')).thenAnswer((_) async => const Right(unit));
        return build();
      },
      seed: () => const VishnuFeedState(savedIds: {'n1'}),
      act: (b) => b.add(const UnsaveFeedNoteEvent('n1')),
      expect: () => [
        isA<VishnuFeedState>().having((s) => s.savedIds, 'savedIds', isEmpty),
      ],
    );
  });

  group('banner + refresh', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'LoadNewNotesEvent advances the anchor to now and reloads from the top',
      build: () {
        when(() => setLoadedAt.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      seed: () => VishnuFeedState(items: [aNote(id: 'stale')], loadedAt: loadedAt, newCount: 3),
      act: (b) => b.add(const LoadNewNotesEvent()),
      verify: (b) {
        expect(b.state.newCount, 0);
        expect(b.state.loadedAt, isNot(loadedAt));
        verify(() => setLoadedAt.call(any())).called(1);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'RefreshFeedEvent delegates to the same reload as the banner tap',
      build: () {
        when(() => setLoadedAt.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      seed: () => VishnuFeedState(loadedAt: loadedAt),
      act: (b) => b.add(const RefreshFeedEvent()),
      verify: (_) {
        verify(() => setLoadedAt.call(any())).called(1);
      },
    );
  });

  group('followed-users watcher', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'ignores the first emission (the current state) and reloads only on '
      'an actual count change',
      build: () {
        when(() => watchFollowed.call(any())).thenAnswer((_) => Stream.fromIterable([
              [FollowedUserEntity(pubkeyHex: 'a', followedAt: DateTime(2026, 1, 1))],
              [
                FollowedUserEntity(pubkeyHex: 'a', followedAt: DateTime(2026, 1, 1)),
                FollowedUserEntity(pubkeyHex: 'b', followedAt: DateTime(2026, 1, 1)),
              ],
            ]));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        // The reload clears items back to [] then re-fetches (still empty
        // here) — the assertion is that it actually attempted a reload,
        // proven via the unread/seen calls firing more than once.
        verify(() => getUnreadPage.call(any())).called(greaterThan(1));
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'an unchanged follow count between emissions does not trigger a '
      'second reload',
      build: () {
        when(() => watchFollowed.call(any())).thenAnswer((_) => Stream.fromIterable([
              [FollowedUserEntity(pubkeyHex: 'a', followedAt: DateTime(2026, 1, 1))],
              [FollowedUserEntity(pubkeyHex: 'a', followedAt: DateTime(2026, 1, 1))],
            ]));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verify(() => getUnreadPage.call(any())).called(1);
      },
    );
  });

  group('banner count', () {
    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'a new-buffer-count emission updates newCount',
      build: () {
        when(() => watchNewCount.call(any())).thenAnswer((_) => Stream.value(5));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.newCount, 5);
      },
    );

    blocTest<VishnuFeedBloc, VishnuFeedState>(
      'an unchanged count does not re-emit',
      build: () {
        when(() => watchNewCount.call(any())).thenAnswer((_) => Stream.fromIterable([0, 0]));
        return build();
      },
      act: (b) => b.add(const FeedOpenedEvent()),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        expect(b.state.newCount, 0);
      },
    );
  });

  group('VishnuFeedState derived getters', () {
    test('isEmpty reflects whether items is empty', () {
      expect(const VishnuFeedState().isEmpty, isTrue);
      expect(VishnuFeedState(items: [aNote()]).isEmpty, isFalse);
    });

    test('hasMore is the negation of exhausted', () {
      expect(const VishnuFeedState(exhausted: false).hasMore, isTrue);
      expect(const VishnuFeedState(exhausted: true).hasMore, isFalse);
    });
  });
}
