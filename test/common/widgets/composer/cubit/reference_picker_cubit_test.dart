import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/common/widgets/composer/cubit/reference_picker_cubit.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/inputs/note_input.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

import '../../../../_helpers/fixtures.dart';

class _MockGetFeed extends Mock implements GetFeedUseCase {}

class _MockSearchNotes extends Mock implements SearchNotesUseCase {}

class _MockGetAllSaved extends Mock implements GetAllSavedNotesUseCase {}

class _MockGetOwnNotes extends Mock implements GetOwnNotesUseCase {}

class _MockGetDrafts extends Mock implements GetDraftsUseCase {}

class _MockGetProfile extends Mock implements GetProfileUseCase {}

class _MockGetKeys extends Mock implements GetActiveUserKeysUseCase {}

DraftEntity _draft({String draftId = 'd1', String content = 'draft body'}) =>
    DraftEntity(
      draftId: draftId,
      content: content,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      createdAt: tNow,
      updatedAt: tNow,
    );

/// Covers: ReferencePickerCubit's init sequence (self pubkey resolution,
/// own-notes tab sourced from a dedicated query only when self pubkey is
/// known, saved/drafts pool loading, profile enrichment kickoff after init),
/// tab switching (query reset, per-tab pool routing), search (server-side
/// for the All tab, local substring filter for every other tab), and
/// profile enrichment (dedup against the cache, best-effort skip on
/// failure).
void main() {
  late _MockGetFeed getFeed;
  late _MockSearchNotes searchNotes;
  late _MockGetAllSaved getAllSaved;
  late _MockGetOwnNotes getOwnNotes;
  late _MockGetDrafts getDrafts;
  late _MockGetProfile getProfile;
  late _MockGetKeys getKeys;

  ReferencePickerCubit build() => ReferencePickerCubit(
        getFeed,
        searchNotes,
        getAllSaved,
        getOwnNotes,
        getDrafts,
        getProfile,
        getKeys,
      );

  setUpAll(() {
    registerFallbackValue(const GetFeedInput(limit: 50));
  });

  setUp(() {
    getFeed = _MockGetFeed();
    searchNotes = _MockSearchNotes();
    getAllSaved = _MockGetAllSaved();
    getOwnNotes = _MockGetOwnNotes();
    getDrafts = _MockGetDrafts();
    getProfile = _MockGetProfile();
    getKeys = _MockGetKeys();

    when(() => getKeys.call())
        .thenAnswer((_) async => const Left(Failure.errorFailure('no user')));
    when(() => getFeed.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getOwnNotes.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getAllSaved.call()).thenAnswer((_) async => const Right([]));
    when(() => getDrafts.call()).thenAnswer((_) async => const Right([]));
    when(() => getProfile.call(any()))
        .thenAnswer((_) async => const Left(Failure.errorFailure('not found')));
  });

  test('starts in the loading state', () {
    final cubit = build();
    expect(cubit.state.loading, isTrue);
    cubit.close();
  });

  test('with no active user, the own-notes tab stays empty and '
      'GetOwnNotesUseCase is never called', () async {
    final cubit = build();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.loading, isFalse);
    verifyZeroInteractions(getOwnNotes);
    cubit.setTab(ReferenceTab.own);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.results, isEmpty);
    await cubit.close();
  });

  test('with an active user, feed/own/saved/drafts all populate and the '
      'All tab renders the feed pool', () async {
    when(() => getKeys.call()).thenAnswer((_) async =>
        const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: kSelfPub)));
    when(() => getFeed.call(const GetFeedInput(limit: 50)))
        .thenAnswer((_) async => Right([aNote(id: 'feed-1')]));
    when(() => getOwnNotes.call(kSelfPub))
        .thenAnswer((_) async => Right([aNote(id: 'own-1', authorPubkey: kSelfPub)]));
    when(() => getAllSaved.call())
        .thenAnswer((_) async => Right([aSavedNote(eventId: 'saved-1')]));
    when(() => getDrafts.call()).thenAnswer((_) async => Right([_draft(draftId: 'd1')]));
    final cubit = build();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.loading, isFalse);
    expect(cubit.state.results.map((r) => r.id), ['feed-1']);

    cubit.setTab(ReferenceTab.own);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.results.map((r) => r.id), ['own-1']);

    cubit.setTab(ReferenceTab.saved);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.results.map((r) => r.id), ['saved-1']);

    cubit.setTab(ReferenceTab.drafts);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.results.single.kind, ComposerReferenceKind.draft);
    expect(cubit.state.results.single.id, 'd1');
    await cubit.close();
  });

  test('setTab to the currently-active tab is a no-op', () async {
    final cubit = build();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final states = <ReferencePickerState>[];
    final sub = cubit.stream.listen(states.add);
    cubit.setTab(ReferenceTab.all);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(states, isEmpty);
    await sub.cancel();
    await cubit.close();
  });

  test('setTab resets the query', () async {
    when(() => searchNotes.call(any())).thenAnswer((_) async => const Right([]));
    final cubit = build();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cubit.search('hello');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.query, 'hello');

    cubit.setTab(ReferenceTab.saved);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.query, '');
    await cubit.close();
  });

  test('a failure on any init query yields an empty pool for that tab, '
      'without crashing', () async {
    when(() => getKeys.call()).thenAnswer((_) async =>
        const Right(UserSigningKeys(privkeyHex: 'priv', pubkeyHex: kSelfPub)));
    when(() => getFeed.call(any()))
        .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
    when(() => getOwnNotes.call(any()))
        .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
    when(() => getAllSaved.call())
        .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
    when(() => getDrafts.call())
        .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
    final cubit = build();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.results, isEmpty);
    for (final tab in ReferenceTab.values) {
      cubit.setTab(tab);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cubit.state.results, isEmpty);
    }
    await cubit.close();
  });

  group('search on the All tab', () {
    test('a non-empty query hits SearchNotesUseCase server-side', () async {
      when(() => searchNotes.call('cats'))
          .thenAnswer((_) async => Right([aNote(id: 'match-1')]));
      final cubit = build();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      cubit.search('cats');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.results.map((r) => r.id), ['match-1']);
      expect(cubit.state.query, 'cats');
    });

    test('a search failure yields an empty result list', () async {
      when(() => searchNotes.call(any()))
          .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
      final cubit = build();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      cubit.search('cats');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.results, isEmpty);
      expect(cubit.state.loading, isFalse);
      await cubit.close();
    });

    test('an empty query on the All tab falls back to the local pool '
        '(no server search)', () async {
      when(() => getFeed.call(any())).thenAnswer((_) async => Right([aNote(id: 'feed-1')]));
      final cubit = build();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      cubit.search('');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.results.map((r) => r.id), ['feed-1']);
      verifyZeroInteractions(searchNotes);
      await cubit.close();
    });
  });

  group('search on non-All tabs', () {
    test('filters the in-memory pool by a case-insensitive label substring',
        () async {
      when(() => getAllSaved.call()).thenAnswer((_) async => Right([
            aSavedNote(eventId: 's1', content: 'Hello World'),
            aSavedNote(eventId: 's2', content: 'Goodbye'),
          ]));
      final cubit = build();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cubit.setTab(ReferenceTab.saved);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      cubit.search('hello');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.results.map((r) => r.id), ['s1']);
      verifyZeroInteractions(searchNotes);
      await cubit.close();
    });
  });

  group('profile enrichment', () {
    test('fetches a profile per distinct author and caches it, skipping '
        'already-cached pubkeys on a later enrichment pass', () async {
      when(() => getFeed.call(any())).thenAnswer((_) async => Right([
            aNote(id: 'n1', authorPubkey: kAlicePub),
            aNote(id: 'n2', authorPubkey: kAlicePub),
          ]));
      when(() => getProfile.call(kAlicePub))
          .thenAnswer((_) async => Right(aProfile(pubkey: kAlicePub)));
      final cubit = build();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.profiles.keys, [kAlicePub]);

      cubit.search('');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => getProfile.call(kAlicePub)).called(1); // fetched only once total
      await cubit.close();
    });

    test('a profile fetch failure is skipped, no crash and no cache entry',
        () async {
      when(() => getFeed.call(any()))
          .thenAnswer((_) async => Right([aNote(id: 'n1', authorPubkey: kAlicePub)]));
      final cubit = build();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.profiles, isEmpty);
      await cubit.close();
    });
  });
}
