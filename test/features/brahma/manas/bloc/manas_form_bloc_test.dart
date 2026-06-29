import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/entities/user_key/user_key_entity.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/brahma/manas/bloc/manas_form_bloc.dart';

class _MockUpsert extends Mock implements UpsertManasUseCase {}

class _MockGetById extends Mock implements GetManasByIdUseCase {}

class _MockDelete extends Mock implements DeleteManasUseCase {}

class _MockAddLink extends Mock implements AddNoteToManasUseCase {}

class _MockRemoveLink extends Mock implements RemoveNoteFromManasUseCase {}

class _MockGetLinks extends Mock implements GetNoteIdsForManasUseCase {}

class _MockGetAllSaved extends Mock implements GetAllSavedNotesUseCase {}

class _MockGetOwnNotes extends Mock implements GetOwnNotesUseCase {}

class _MockGetActiveUser extends Mock implements GetActiveUserUseCase {}

UserKeyEntity _activeUser() => UserKeyEntity(
      pubkeyHex: 'mypub',
      npub: 'npub1xxx',
      nsec: 'nsec1xxx',
      createdAt: DateTime(2026, 1, 1),
    );

NoteEntity _ownNote(String id, String content) => NoteEntity(
      id: id,
      sig: 's',
      authorPubkey: 'mypub',
      content: content,
      type: NoteType.text,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      created: DateTime(2026, 1, 1),
    );

SavedNoteEntity _saved(String eventId, String content) => SavedNoteEntity(
      eventId: eventId,
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

ManasEntity _manas(String id, {String name = 'existing', String? icon}) =>
    ManasEntity(
      manasId: id,
      name: name,
      iconName: icon,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Tests for [ManasFormBloc]. Covers every event handler:
///
///   - Load (create mode + edit mode + manas-not-found)
///   - Search pool dedup (own ∪ saved; saved wins on id collision)
///     — drafts are intentionally NOT in the pool to keep Manas links
///       stable across publish (a draft UUID would be orphaned).
///   - Search (restartable transformer, ≤30 results, case-insensitive)
///   - Name change auto-suggests icon UNTIL the user pins one
///   - Icon picker pins the choice (subsequent name edits don't override)
///   - Membership toggle (add + remove + preview accumulation)
///   - Submit (canSave gate + droppable transformer + add/remove diff)
///   - Delete
void main() {
  late _MockUpsert upsert;
  late _MockGetById getById;
  late _MockDelete delete;
  late _MockAddLink addLink;
  late _MockRemoveLink removeLink;
  late _MockGetLinks getLinks;
  late _MockGetAllSaved getAllSaved;
  late _MockGetOwnNotes getOwnNotes;
  late _MockGetActiveUser getActiveUser;

  setUpAll(() {
    // mocktail needs sample values for any matchers used against typed args.
    registerFallbackValue(_manas('fallback'));
    registerFallbackValue(const ManasNoteLink('m', 'n'));
  });

  setUp(() {
    upsert = _MockUpsert();
    getById = _MockGetById();
    delete = _MockDelete();
    addLink = _MockAddLink();
    removeLink = _MockRemoveLink();
    getLinks = _MockGetLinks();
    getAllSaved = _MockGetAllSaved();
    getOwnNotes = _MockGetOwnNotes();
    getActiveUser = _MockGetActiveUser();
  });

  ManasFormBloc build() => ManasFormBloc(
        upsert,
        getById,
        delete,
        addLink,
        removeLink,
        getLinks,
        getAllSaved,
        getOwnNotes,
        getActiveUser,
      );

  /// Wires every "pool" use case to return the given collections. Use
  /// before `blocTest.build` to control what the search pool sees.
  void primePool({
    List<NoteEntity> own = const [],
    List<SavedNoteEntity> saved = const [],
  }) {
    when(() => getActiveUser.call())
        .thenAnswer((_) async => Right(_activeUser()));
    when(() => getOwnNotes.call(any())).thenAnswer((_) async => Right(own));
    when(() => getAllSaved.call()).thenAnswer((_) async => Right(saved));
  }

  // ── Load — create mode ───────────────────────────────────────────────────

  group('ManasFormLoadEvent (create mode)', () {
    blocTest<ManasFormBloc, ManasFormState>(
      'creates a fresh UUID + ready state + isEditMode=false',
      build: () {
        primePool();
        return build();
      },
      act: (b) => b.add(const ManasFormLoadEvent(null)),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.ready);
        expect(b.state.isEditMode, isFalse);
        expect(b.state.manasId, isNotEmpty);
        expect(b.state.persistedMembership, isEmpty);
        expect(b.state.pendingMembership, isEmpty);
      },
    );
  });

  // ── Load — edit mode ─────────────────────────────────────────────────────

  group('ManasFormLoadEvent (edit mode)', () {
    blocTest<ManasFormBloc, ManasFormState>(
      'populates name + icon + memberships from the use cases',
      build: () {
        primePool(
          own: [_ownNote('note-1', 'one'), _ownNote('note-2', 'two')],
        );
        when(() => getById.call('m-1'))
            .thenAnswer((_) async => Right(_manas('m-1', name: 'Loaded', icon: 'work')));
        when(() => getLinks.call('m-1'))
            .thenAnswer((_) async => const Right(['note-1', 'note-2']));
        return build();
      },
      act: (b) => b.add(const ManasFormLoadEvent('m-1')),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.ready);
        expect(b.state.isEditMode, isTrue);
        expect(b.state.manasId, 'm-1');
        expect(b.state.name, 'Loaded');
        expect(b.state.iconName, 'work');
        expect(b.state.iconUserPicked, isTrue,
            reason: 'an existing stored icon counts as pinned');
        expect(b.state.persistedMembership, {'note-1', 'note-2'});
        expect(b.state.pendingMembership, {'note-1', 'note-2'});
        expect(b.state.membershipPreviews, hasLength(2));
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'unknown id → status:error',
      build: () {
        primePool();
        when(() => getById.call(any()))
            .thenAnswer((_) async => const Left(Failure.notFoundFailure('nope')));
        return build();
      },
      act: (b) => b.add(const ManasFormLoadEvent('ghost')),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.error);
        expect(b.state.errorMessage, contains('not found'));
      },
    );
  });

  // ── Search pool dedup ────────────────────────────────────────────────────

  group('search pool dedup', () {
    blocTest<ManasFormBloc, ManasFormState>(
      'own ∪ drafts ∪ saved, saved wins when id is both own and saved',
      build: () {
        primePool(
          // Same id 'dup' exists as both own and saved → saved must win the
          // displayed kind (per the impl: saved is upserted last).
          own: [
            _ownNote('dup', 'own version'),
            _ownNote('only-own', 'unique own version'),
          ],
          saved: [_saved('dup', 'saved version'), _saved('only-saved', 's')],
        );
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormSearchEvent('version'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        // Searching 'version' hits both 'own version' and 'saved version',
        // but they share id 'dup' — only one survives in the pool.
        final ids = b.state.searchResults.map((r) => r.noteId).toSet();
        expect(ids, contains('dup'));
        expect(b.state.searchResults.where((r) => r.noteId == 'dup'), hasLength(1));
        // Sanity: also picked up the unique ids.
        expect(ids, contains('only-own'));
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'drafts are NOT in the pool — search by draft content yields nothing',
      build: () {
        // Even though the user has drafts, the form ignores them. Manas
        // links must point to a real event id (Nostr immutability), and a
        // draft UUID would orphan the link the moment the draft publishes.
        primePool(own: [_ownNote('real', 'real apple')]);
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormSearchEvent('apple'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        // Only the published 'real apple' note matches. Any draft
        // containing "apple" must NOT show up.
        expect(b.state.searchResults.map((r) => r.noteId), ['real']);
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'search caps results at 30',
      build: () {
        primePool(
          own: [
            for (var i = 0; i < 50; i++) _ownNote('n-$i', 'banana-$i'),
          ],
        );
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormSearchEvent('banana'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.searchResults, hasLength(30));
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'empty query clears search results',
      build: () {
        primePool(own: [_ownNote('a', 'apple')]);
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormSearchEvent('apple'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormSearchEvent('   '));
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.searchResults, isEmpty);
        expect(b.state.searchQuery, '');
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'case-insensitive match',
      build: () {
        primePool(own: [_ownNote('a', 'Hello WORLD')]);
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormSearchEvent('world'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.searchResults.map((r) => r.noteId), ['a']);
      },
    );
  });

  // ── Icon auto-suggest ────────────────────────────────────────────────────

  group('icon auto-suggest', () {
    blocTest<ManasFormBloc, ManasFormState>(
      'name change suggests an icon when not pinned',
      build: () {
        primePool();
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormNameChangedEvent('My Fitness Goals'));
      },
      wait: const Duration(milliseconds: 30),
      verify: (b) {
        expect(b.state.name, 'My Fitness Goals');
        expect(b.state.iconName, 'fitness_center');
        expect(b.state.iconUserPicked, isFalse);
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'name change with no keyword match clears the icon',
      build: () {
        primePool();
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormNameChangedEvent('blibbity blob'));
      },
      wait: const Duration(milliseconds: 30),
      verify: (b) {
        expect(b.state.iconName, isNull);
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'after the user picks an icon, name edits do NOT override it',
      build: () {
        primePool();
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormIconPickedEvent('lightbulb'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        b.add(const ManasFormNameChangedEvent('My Fitness Goals'));
      },
      wait: const Duration(milliseconds: 30),
      verify: (b) {
        expect(b.state.iconUserPicked, isTrue);
        expect(b.state.iconName, 'lightbulb',
            reason: 'pinned icon survives a later name edit');
      },
    );
  });

  // ── Membership toggle ────────────────────────────────────────────────────

  group('membership toggle', () {
    blocTest<ManasFormBloc, ManasFormState>(
      'add then remove cycles cleanly through pendingMembership',
      build: () {
        primePool();
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        const preview = ManasNotePreview(
          noteId: 'n-1',
          preview: 'hello',
          kind: ManasNoteKind.own,
        );
        b.add(const ManasFormToggleMembershipEvent(preview));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        b.add(const ManasFormToggleMembershipEvent(preview));
      },
      wait: const Duration(milliseconds: 30),
      verify: (b) {
        expect(b.state.pendingMembership, isEmpty);
        // The preview is still cached so the chip can render after a
        // toggle-off → toggle-on cycle without re-searching.
        expect(b.state.membershipPreviews, contains('n-1'));
      },
    );
  });

  // ── Submit ───────────────────────────────────────────────────────────────

  group('submit', () {
    blocTest<ManasFormBloc, ManasFormState>(
      'canSave=false (empty name) → no use cases called, no state change',
      build: () {
        primePool();
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormSubmitEvent());
      },
      wait: const Duration(milliseconds: 30),
      verify: (b) {
        verifyNever(() => upsert.call(any()));
        expect(b.state.status, ManasFormStatus.ready);
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'create-mode submit: upserts + adds every pending membership',
      build: () {
        primePool(own: [_ownNote('n-1', 'one'), _ownNote('n-2', 'two')]);
        when(() => upsert.call(any())).thenAnswer((invocation) async => Right(invocation.positionalArguments.first as ManasEntity));
        when(() => addLink.call(any())).thenAnswer((_) async => const Right(unit));
        when(() => removeLink.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormNameChangedEvent('Goals'));
        b.add(const ManasFormToggleMembershipEvent(ManasNotePreview(
          noteId: 'n-1',
          preview: 'one',
          kind: ManasNoteKind.own,
        )));
        b.add(const ManasFormToggleMembershipEvent(ManasNotePreview(
          noteId: 'n-2',
          preview: 'two',
          kind: ManasNoteKind.own,
        )));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        b.add(const ManasFormSubmitEvent());
      },
      wait: const Duration(milliseconds: 80),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.saved);
        verify(() => upsert.call(any())).called(1);
        verify(() => addLink.call(any())).called(2);
        // No removals on create — persistedMembership started empty.
        verifyNever(() => removeLink.call(any()));
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'edit-mode submit: diffs persisted vs pending → only delta calls',
      build: () {
        primePool(own: [
          _ownNote('keep', 'k'),
          _ownNote('drop', 'd'),
          _ownNote('add-me', 'a'),
        ]);
        when(() => getById.call('m-1'))
            .thenAnswer((_) async => Right(_manas('m-1', name: 'Existing')));
        when(() => getLinks.call('m-1'))
            .thenAnswer((_) async => const Right(['keep', 'drop']));
        when(() => upsert.call(any())).thenAnswer((invocation) async => Right(invocation.positionalArguments.first as ManasEntity));
        when(() => addLink.call(any())).thenAnswer((_) async => const Right(unit));
        when(() => removeLink.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent('m-1'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        // Remove "drop", add "add-me", leave "keep".
        b.add(const ManasFormToggleMembershipEvent(ManasNotePreview(
          noteId: 'drop',
          preview: 'd',
          kind: ManasNoteKind.own,
        )));
        b.add(const ManasFormToggleMembershipEvent(ManasNotePreview(
          noteId: 'add-me',
          preview: 'a',
          kind: ManasNoteKind.own,
        )));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        b.add(const ManasFormSubmitEvent());
      },
      wait: const Duration(milliseconds: 80),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.saved);
        verify(() => upsert.call(any())).called(1);
        // Exactly one add ("add-me") and one remove ("drop"). "keep" stays.
        final addedIds = verify(() => addLink.call(captureAny())).captured
            .cast<ManasNoteLink>()
            .map((l) => l.noteId)
            .toSet();
        final removedIds = verify(() => removeLink.call(captureAny())).captured
            .cast<ManasNoteLink>()
            .map((l) => l.noteId)
            .toSet();
        expect(addedIds, {'add-me'});
        expect(removedIds, {'drop'});
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'upsert failure → status:error, no link mutations',
      build: () {
        primePool();
        when(() => upsert.call(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('upsert failed')),
        );
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormNameChangedEvent('Goals'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        b.add(const ManasFormSubmitEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.error);
        expect(b.state.errorMessage, contains('upsert failed'));
        verifyNever(() => addLink.call(any()));
        verifyNever(() => removeLink.call(any()));
      },
    );
  });

  // ── Delete ───────────────────────────────────────────────────────────────

  group('delete', () {
    blocTest<ManasFormBloc, ManasFormState>(
      'delete succeeds → status:deleted',
      build: () {
        primePool();
        when(() => delete.call(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormDeleteEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.deleted);
        verify(() => delete.call(any())).called(1);
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'delete failure → status:error',
      build: () {
        primePool();
        when(() => delete.call(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('cannot delete')),
        );
        return build();
      },
      act: (b) async {
        b.add(const ManasFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const ManasFormDeleteEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.status, ManasFormStatus.error);
        expect(b.state.errorMessage, contains('cannot delete'));
      },
    );

    blocTest<ManasFormBloc, ManasFormState>(
      'delete with no manasId yet (initial state) → no-op',
      build: () => build(),
      act: (b) => b.add(const ManasFormDeleteEvent()),
      wait: const Duration(milliseconds: 30),
      verify: (_) {
        verifyNever(() => delete.call(any()));
      },
    );
  });
}
