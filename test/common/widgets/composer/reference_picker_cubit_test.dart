import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/common/widgets/composer/cubit/reference_picker_cubit.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/inputs/note_input.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

class _MGetFeed extends Mock implements GetFeedUseCase {}

class _MSearchNotes extends Mock implements SearchNotesUseCase {}

class _MGetAllSaved extends Mock implements GetAllSavedNotesUseCase {}

class _MGetOwn extends Mock implements GetOwnNotesUseCase {}

class _MGetDrafts extends Mock implements GetDraftsUseCase {}

class _MGetProfile extends Mock implements GetProfileUseCase {}

class _MGetKeys extends Mock implements GetActiveUserKeysUseCase {}

NoteEntity _note(String id, String content,
        {String? pubkey, DateTime? created}) =>
    NoteEntity(
      id: id,
      sig: 's',
      authorPubkey: pubkey ?? 'pub-$id',
      content: content,
      type: NoteType.text,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      created: created ?? DateTime(2026, 1, 1),
    );

SavedNoteEntity _saved(String id, String content) => SavedNoteEntity(
      eventId: id,
      sig: 's',
      authorPubkey: 'someone',
      content: content,
      type: NoteType.text,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      created: DateTime(2026, 1, 1),
      savedAt: DateTime(2026, 1, 1),
    );

DraftEntity _draft(String id, String content) => DraftEntity(
      draftId: id,
      content: content,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Tests for [ReferencePickerCubit]. Covers the composer's note-reference
/// picker — every tab (All / Saved / Own / Drafts), search behaviour per
/// tab, profile enrichment, and the construction of draft refs with
/// `ComposerReferenceKind.draft` so the chip renders correctly.
///
/// The All tab calls `SearchNotesUseCase` against the unified Note
/// collection; every other tab filters its in-memory pool locally.
void main() {
  late _MGetFeed getFeed;
  late _MSearchNotes searchNotes;
  late _MGetAllSaved getAllSaved;
  late _MGetOwn getOwn;
  late _MGetDrafts getDrafts;
  late _MGetProfile getProfile;
  late _MGetKeys getKeys;

  setUpAll(() {
    registerFallbackValue(const GetFeedInput(limit: 50));
  });

  setUp(() {
    getFeed = _MGetFeed();
    searchNotes = _MSearchNotes();
    getAllSaved = _MGetAllSaved();
    getOwn = _MGetOwn();
    getDrafts = _MGetDrafts();
    getProfile = _MGetProfile();
    getKeys = _MGetKeys();

    // Default benign responses — individual tests override what they need.
    when(() => getKeys.call()).thenAnswer((_) async => const Right(
          UserSigningKeys(
            privkeyHex:
                '0000000000000000000000000000000000000000000000000000000000000001',
            pubkeyHex:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ));
    when(() => getFeed.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getOwn.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getAllSaved.call()).thenAnswer((_) async => const Right([]));
    when(() => getDrafts.call()).thenAnswer((_) async => const Right([]));
    when(() => searchNotes.call(any())).thenAnswer((_) async => const Right([]));
    when(() => getProfile.call(any())).thenAnswer(
      (_) async => const Left(Failure.notFoundFailure('no profile')),
    );
  });

  ReferencePickerCubit build() => ReferencePickerCubit(
        getFeed,
        searchNotes,
        getAllSaved,
        getOwn,
        getDrafts,
        getProfile,
        getKeys,
      );

  // ── Initial load ────────────────────────────────────────────────────────

  group('initial load', () {
    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'loads All tab from the feed; state becomes loading=false with results',
      build: () {
        when(() => getFeed.call(any())).thenAnswer((_) async => Right([
              _note('a', 'apple'),
              _note('b', 'banana'),
            ]));
        return build();
      },
      wait: const Duration(milliseconds: 50),
      verify: (c) {
        expect(c.state.loading, isFalse);
        expect(c.state.results.map((r) => r.id), ['a', 'b']);
        expect(c.state.tab, ReferenceTab.all);
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'no active user keys → own pool stays empty (no GetOwnNotes call)',
      build: () {
        when(() => getKeys.call()).thenAnswer(
          (_) async => const Left(Failure.notFoundFailure('no user')),
        );
        return build();
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        verifyNever(() => getOwn.call(any()));
      },
    );
  });

  // ── Tab switching ──────────────────────────────────────────────────────

  group('setTab', () {
    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'switching to saved exposes the saved pool',
      build: () {
        when(() => getAllSaved.call()).thenAnswer((_) async =>
            Right([_saved('s-1', 'saved one'), _saved('s-2', 'saved two')]));
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.setTab(ReferenceTab.saved);
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        expect(c.state.tab, ReferenceTab.saved);
        expect(c.state.results.map((r) => r.id), ['s-1', 's-2']);
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'switching to drafts exposes drafts with kind=draft',
      build: () {
        when(() => getDrafts.call()).thenAnswer((_) async => Right([
              _draft('d-1', 'draft one'),
              _draft('d-2', 'draft two'),
            ]));
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.setTab(ReferenceTab.drafts);
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        expect(c.state.tab, ReferenceTab.drafts);
        expect(c.state.results.map((r) => r.id), ['d-1', 'd-2']);
        // Every draft ref carries the draft kind so the chip renders the
        // "DRAFT" badge.
        for (final r in c.state.results) {
          expect(r.kind, ComposerReferenceKind.draft);
        }
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'switching tabs clears the active query',
      build: () => build(),
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.search('something');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.setTab(ReferenceTab.saved);
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        expect(c.state.query, '');
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'setTab to the SAME tab is a no-op (no emit)',
      build: () => build(),
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.setTab(ReferenceTab.all);
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        expect(c.state.tab, ReferenceTab.all);
      },
    );
  });

  // ── Search ─────────────────────────────────────────────────────────────

  group('search', () {
    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'All tab + non-empty query → calls SearchNotesUseCase',
      build: () {
        when(() => searchNotes.call('apple')).thenAnswer((_) async => Right([
              _note('a', 'apple pie'),
            ]));
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.search('apple');
      },
      wait: const Duration(milliseconds: 50),
      verify: (c) {
        verify(() => searchNotes.call('apple')).called(1);
        expect(c.state.results.map((r) => r.id), ['a']);
        expect(c.state.query, 'apple');
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'Saved tab + query filters the in-memory pool, does NOT call SearchNotes',
      build: () {
        when(() => getAllSaved.call()).thenAnswer((_) async => Right([
              _saved('s-1', 'apple seed'),
              _saved('s-2', 'banana split'),
            ]));
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.setTab(ReferenceTab.saved);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.search('apple');
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        verifyNever(() => searchNotes.call(any()));
        expect(c.state.results.map((r) => r.id), ['s-1']);
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'Drafts tab + query filters drafts locally (case-insensitive)',
      build: () {
        when(() => getDrafts.call()).thenAnswer((_) async => Right([
              _draft('d-1', 'Hello WORLD'),
              _draft('d-2', 'goodbye'),
            ]));
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.setTab(ReferenceTab.drafts);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.search('world');
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        expect(c.state.results.map((r) => r.id), ['d-1']);
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'empty query on a non-All tab restores the full pool',
      build: () {
        when(() => getOwn.call(any())).thenAnswer((_) async => Right([
              _note('o-1', 'one'),
              _note('o-2', 'two'),
            ]));
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.setTab(ReferenceTab.own);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.search('one');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.search('');
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        expect(c.state.results.map((r) => r.id), ['o-1', 'o-2']);
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'whitespace-only query is treated as empty',
      build: () {
        when(() => getOwn.call(any())).thenAnswer(
            (_) async => Right([_note('o-1', 'apple'), _note('o-2', 'pear')]));
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.setTab(ReferenceTab.own);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.search('   ');
      },
      wait: const Duration(milliseconds: 30),
      verify: (c) {
        // Whitespace q.trim() empty → restores pool.
        expect(c.state.results.map((r) => r.id), ['o-1', 'o-2']);
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'SearchNotesUseCase failure → empty results, no crash',
      build: () {
        when(() => searchNotes.call(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('search broke')),
        );
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        c.search('anything');
      },
      wait: const Duration(milliseconds: 50),
      verify: (c) {
        expect(c.state.loading, isFalse);
        expect(c.state.results, isEmpty);
      },
    );
  });

  // ── Profile enrichment ─────────────────────────────────────────────────

  group('profile enrichment', () {
    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'fetches profiles for the visible rows and emits an enriched state',
      build: () {
        when(() => getFeed.call(any())).thenAnswer((_) async => Right([
              _note('a', 'one', pubkey: 'pub-A'),
              _note('b', 'two', pubkey: 'pub-B'),
            ]));
        when(() => getProfile.call('pub-A')).thenAnswer((_) async => Right(
              ProfileEntity(pubkey: 'pub-A', name: 'Alice', updatedAt: DateTime(2026)),
            ));
        when(() => getProfile.call('pub-B')).thenAnswer((_) async => Right(
              ProfileEntity(pubkey: 'pub-B', name: 'Bob', updatedAt: DateTime(2026)),
            ));
        return build();
      },
      wait: const Duration(milliseconds: 100),
      verify: (c) {
        expect(c.state.profiles.keys, containsAll(['pub-A', 'pub-B']));
        expect(c.state.profiles['pub-A']?.name, 'Alice');
        expect(c.state.profiles['pub-B']?.name, 'Bob');
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'profile lookup failure is silently skipped — pubkey absent from cache',
      build: () {
        when(() => getFeed.call(any())).thenAnswer((_) async => Right([
              _note('a', 'one', pubkey: 'pub-A'),
            ]));
        when(() => getProfile.call('pub-A')).thenAnswer(
          (_) async => const Left(Failure.notFoundFailure('no')),
        );
        return build();
      },
      wait: const Duration(milliseconds: 100),
      verify: (c) {
        expect(c.state.profiles.containsKey('pub-A'), isFalse);
        // Still finished loading — the failure didn't break the picker.
        expect(c.state.loading, isFalse);
      },
    );

    blocTest<ReferencePickerCubit, ReferencePickerState>(
      'cached pubkeys are NOT re-fetched on a subsequent search emit',
      build: () {
        when(() => getFeed.call(any())).thenAnswer((_) async => Right([
              _note('a', 'apple', pubkey: 'pub-A'),
            ]));
        when(() => getProfile.call('pub-A')).thenAnswer((_) async => Right(
              ProfileEntity(pubkey: 'pub-A', name: 'Alice', updatedAt: DateTime(2026)),
            ));
        when(() => searchNotes.call(any())).thenAnswer(
          (_) async => Right([_note('a', 'apple', pubkey: 'pub-A')]),
        );
        return build();
      },
      act: (c) async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        c.search('apple');
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        // Initial load + search both saw pub-A. The profile lookup must
        // have run exactly ONCE.
        verify(() => getProfile.call('pub-A')).called(1);
      },
    );
  });
}
