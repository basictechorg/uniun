import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/nataraj_card_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/domain/usecases/nataraj_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/shiv/nataraj/bloc/nataraj_bloc.dart';
import 'package:uniun/features/shiv/nataraj/engine/nataraj_generator.dart';

import '../../../../_helpers/fixtures.dart';

class _MockGenerator extends Mock implements NatarajGenerator {}

class _MockNext extends Mock implements GetNextNatarajCardUseCase {}

class _MockRecord extends Mock implements RecordNatarajSwipeUseCase {}

class _MockManasList extends Mock implements GetManasListUseCase {}

class _MockKeys extends Mock implements GetActiveUserKeysUseCase {}

class _MockPublish extends Mock implements PublishNoteUseCase {}

class _MockSaveDraft extends Mock implements SaveDraftUseCase {}

NatarajCardEntity _card({
  String scopeId = 'all',
  String signature = 'sig1',
  List<String> noteIds = const [],
  String paragraph = 'generated text',
}) =>
    NatarajCardEntity(
      scopeId: scopeId,
      signature: signature,
      noteIds: noteIds,
      generatedParagraph: paragraph,
      status: NatarajCardStatus.buffered,
      createdAt: DateTime(2026, 1, 1),
    );

ManasEntity _manas(String id, String name) => ManasEntity(
      manasId: id,
      name: name,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockGenerator generator;
  late _MockNext next;
  late _MockRecord record;
  late _MockManasList manasList;
  late _MockKeys keys;
  late _MockPublish publish;
  late _MockSaveDraft saveDraft;

  setUpAll(() {
    registerFallbackValue(const RecordNatarajSwipeInput(
      scopeId: 'x',
      signature: 'x',
      status: NatarajCardStatus.seen,
    ));
    registerFallbackValue(aNote());
    registerFallbackValue(DraftEntity(
      draftId: 'x',
      content: 'x',
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
  });

  NatarajBloc build() => NatarajBloc(
        generator,
        next,
        record,
        manasList,
        keys,
        publish,
        saveDraft,
      );

  setUp(() {
    generator = _MockGenerator();
    next = _MockNext();
    record = _MockRecord();
    manasList = _MockManasList();
    keys = _MockKeys();
    publish = _MockPublish();
    saveDraft = _MockSaveDraft();

    when(() => generator.fillBuffer(
          manasIds: any(named: 'manasIds'),
          count: any(named: 'count'),
        )).thenAnswer(
        (_) async => const NatarajFillResult(inserted: 1, state: NatarajFillState.ok));
    when(() => manasList.call())
        .thenAnswer((_) async => Right([_manas('m1', 'Work')]));
    when(() => record.call(any())).thenAnswer((_) async => const Right(unit));
  });

  group('loadDeck', () {
    blocTest<NatarajBloc, NatarajState>(
      'loads manas options, fills the buffer, and shows the first card',
      build: build,
      setUp: () {
        when(() => next.call(any()))
            .thenAnswer((_) async => Right(_card(signature: 'first')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1'])),
      expect: () => [
        isA<NatarajState>()
            .having((s) => s.status, 'status', NatarajStatus.loading)
            .having((s) => s.manasOptions, 'manasOptions', [_manas('m1', 'Work')]),
        isA<NatarajState>()
            .having((s) => s.status, 'status', NatarajStatus.ready)
            .having((s) => s.currentCard?.signature, 'currentCard', 'first'),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      'single-Manas scope resolves scopeName from manasOptions',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
        when(() => generator.fillBuffer(
              manasIds: any(named: 'manasIds'),
              count: any(named: 'count'),
            )).thenAnswer((_) async =>
            const NatarajFillResult(inserted: 0, state: NatarajFillState.exhausted));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1'])),
      expect: () => [
        isA<NatarajState>().having((s) => s.scopeName, 'scopeName', 'Work'),
        isA<NatarajState>().having((s) => s.status, 'status', NatarajStatus.exhausted),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      'multi-Manas / empty scope resolves scopeName to empty string',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1', 'm2'])),
      expect: () => [
        isA<NatarajState>().having((s) => s.scopeName, 'scopeName', ''),
        isA<NatarajState>(),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      'a single manasId not found in manasOptions falls back to empty '
      'scopeName',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['unknown'])),
      expect: () => [
        isA<NatarajState>().having((s) => s.scopeName, 'scopeName', ''),
        isA<NatarajState>(),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      'needsMoreNotes/error/ok/resurfacing fill states with no card all map '
      'to a non-ready status',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
        when(() => generator.fillBuffer(
              manasIds: any(named: 'manasIds'),
              count: any(named: 'count'),
            )).thenAnswer((_) async =>
            const NatarajFillResult(inserted: 0, state: NatarajFillState.needsMoreNotes));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1'])),
      expect: () => [
        isA<NatarajState>(),
        isA<NatarajState>()
            .having((s) => s.status, 'status', NatarajStatus.needsMoreNotes)
            .having((s) => s.currentCard, 'currentCard', isNull),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      // Regression test: a resurfacing/ok fill that lands no card is NOT a
      // failure (generation succeeded) — it must NEVER map to
      // NatarajStatus.error (which renders the misleading "AI model
      // couldn't run on this device" copy). See issue root-caused via a
      // real-device repro: a noop LLM response reports NatarajFillState.ok,
      // and used to incorrectly surface the model-error screen.
      'a resurfacing fill state with no card to show maps to noIdea, NOT '
      'error (only a resurfacing fill WITH a card sets '
      'state.resurfacing:true)',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
        when(() => generator.fillBuffer(
              manasIds: any(named: 'manasIds'),
              count: any(named: 'count'),
            )).thenAnswer((_) async => const NatarajFillResult(
            inserted: 0, state: NatarajFillState.resurfacing));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1'])),
      expect: () => [
        isA<NatarajState>(),
        isA<NatarajState>()
            .having((s) => s.status, 'status', NatarajStatus.noIdea)
            .having((s) => s.status, 'status', isNot(NatarajStatus.error)),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      'an ok fill state with no card (e.g. a noop LLM response) maps to '
      'noIdea, NOT error',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
        when(() => generator.fillBuffer(
              manasIds: any(named: 'manasIds'),
              count: any(named: 'count'),
            )).thenAnswer((_) async =>
            const NatarajFillResult(inserted: 0, state: NatarajFillState.ok));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1'])),
      expect: () => [
        isA<NatarajState>(),
        isA<NatarajState>()
            .having((s) => s.status, 'status', NatarajStatus.noIdea)
            .having((s) => s.status, 'status', isNot(NatarajStatus.error)),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      // Negative-space check for the fix above: a GENUINE failure must
      // still surface as NatarajStatus.error (the model-error UI is
      // correct there) — the fix must not also swallow real errors.
      'a genuine NatarajFillState.error with no card still maps to '
      'NatarajStatus.error, NOT noIdea',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
        when(() => generator.fillBuffer(
              manasIds: any(named: 'manasIds'),
              count: any(named: 'count'),
            )).thenAnswer((_) async =>
            const NatarajFillResult(inserted: 0, state: NatarajFillState.error));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1'])),
      expect: () => [
        isA<NatarajState>(),
        isA<NatarajState>()
            .having((s) => s.status, 'status', NatarajStatus.error)
            .having((s) => s.status, 'status', isNot(NatarajStatus.noIdea)),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      'a manasList failure still proceeds with empty options (getOrElse)',
      build: build,
      setUp: () {
        when(() => manasList.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('x')));
        when(() => next.call(any()))
            .thenAnswer((_) async => Right(_card()));
      },
      act: (bloc) => bloc.add(const NatarajEvent.loadDeck(['m1'])),
      expect: () => [
        isA<NatarajState>().having((s) => s.manasOptions, 'manasOptions', isEmpty),
        isA<NatarajState>(),
      ],
    );
  });

  group('changeScope', () {
    blocTest<NatarajBloc, NatarajState>(
      'resets resurfacing to false and reloads for the new scope',
      build: build,
      setUp: () {
        when(() => next.call(any())).thenAnswer((_) async => Right(_card()));
      },
      seed: () => const NatarajState(resurfacing: true, manasOptions: []),
      act: (bloc) => bloc.add(const NatarajEvent.changeScope(['m2'])),
      expect: () => [
        isA<NatarajState>().having((s) => s.resurfacing, 'resurfacing', false),
        isA<NatarajState>(),
      ],
    );
  });

  group('toggleReference', () {
    blocTest<NatarajBloc, NatarajState>(
      'adds an unreferenced noteId to excludedRefIds',
      build: build,
      act: (bloc) => bloc.add(const NatarajEvent.toggleReference('n1')),
      expect: () => [
        isA<NatarajState>().having((s) => s.excludedRefIds, 'excludedRefIds', {'n1'}),
      ],
    );

    blocTest<NatarajBloc, NatarajState>(
      'removes an already-excluded noteId (toggle back)',
      build: build,
      seed: () => const NatarajState(excludedRefIds: {'n1'}),
      act: (bloc) => bloc.add(const NatarajEvent.toggleReference('n1')),
      expect: () => [
        isA<NatarajState>().having((s) => s.excludedRefIds, 'excludedRefIds', isEmpty),
      ],
    );
  });

  group('loadMore', () {
    blocTest<NatarajBloc, NatarajState>(
      'fills the buffer to the target size for the current scope',
      build: build,
      seed: () => const NatarajState(manasIds: ['m1']),
      act: (bloc) => bloc.add(const NatarajEvent.loadMore()),
      verify: (_) {
        verify(() => generator.fillBuffer(manasIds: ['m1'], count: 5)).called(1);
      },
      expect: () => [],
    );
  });

  group('swipeCard', () {
    blocTest<NatarajBloc, NatarajState>(
      'no-op when there is no current card',
      build: build,
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.left)),
      expect: () => [],
    );

    blocTest<NatarajBloc, NatarajState>(
      'left (discard): marks discarded and advances to the buffered next '
      'card',
      build: build,
      seed: () => NatarajState(currentCard: _card(signature: 'cur')),
      setUp: () {
        when(() => next.call(any()))
            .thenAnswer((_) async => Right(_card(signature: 'nxt')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.left)),
      expect: () => [
        isA<NatarajState>().having((s) => s.currentCard?.signature, 'card', 'nxt'),
      ],
      verify: (_) {
        verify(() => record.call(any(
              that: isA<RecordNatarajSwipeInput>()
                  .having((i) => i.status, 'status', NatarajCardStatus.discarded),
            ))).called(1);
      },
    );

    blocTest<NatarajBloc, NatarajState>(
      'down (seen): marks seen, sets seedChatParagraph, advances',
      build: build,
      seed: () => NatarajState(
          currentCard: _card(signature: 'cur', paragraph: 'seed me')),
      setUp: () {
        when(() => next.call(any()))
            .thenAnswer((_) async => Right(_card(signature: 'nxt')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.down)),
      expect: () => [
        isA<NatarajState>()
            .having((s) => s.seedChatParagraph, 'seedChatParagraph', 'seed me'),
      ],
      verify: (_) {
        verify(() => record.call(any(
              that: isA<RecordNatarajSwipeInput>()
                  .having((i) => i.status, 'status', NatarajCardStatus.seen),
            ))).called(1);
      },
    );

    blocTest<NatarajBloc, NatarajState>(
      'up (publish): a successful publish marks published, advances, and '
      'excludes toggled-off references',
      build: build,
      seed: () => NatarajState(
        currentCard: _card(noteIds: [
          '1' * 64, // valid event id shape
          'not-an-event-id',
        ]),
        excludedRefIds: const {},
      ),
      setUp: () {
        when(() => keys.call()).thenAnswer((_) async => const Right(kSigningKeys));
        when(() => publish.call(any())).thenAnswer((_) async => Right(aNote()));
        when(() => next.call(any())).thenAnswer((_) async => const Right(null));
        when(() => generator.fillBuffer(
              manasIds: any(named: 'manasIds'),
              count: any(named: 'count'),
            )).thenAnswer((_) async =>
            const NatarajFillResult(inserted: 0, state: NatarajFillState.exhausted));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.up)),
      expect: () => [
        isA<NatarajState>().having((s) => s.status, 'status', NatarajStatus.loading),
        isA<NatarajState>().having((s) => s.status, 'status', NatarajStatus.exhausted),
      ],
      verify: (_) {
        verify(() => publish.call(any())).called(1);
        verify(() => record.call(any(
              that: isA<RecordNatarajSwipeInput>()
                  .having((i) => i.status, 'status', NatarajCardStatus.published),
            ))).called(1);
      },
    );

    blocTest<NatarajBloc, NatarajState>(
      'up (publish): no active signing keys aborts before publishing or '
      'marking, emits nothing',
      build: build,
      seed: () => NatarajState(currentCard: _card()),
      setUp: () {
        when(() => keys.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('no keys')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.up)),
      expect: () => [],
      verify: (_) {
        verifyNever(() => publish.call(any()));
        verifyNever(() => record.call(any()));
      },
    );

    blocTest<NatarajBloc, NatarajState>(
      'up (publish): a publish failure aborts before marking or advancing',
      build: build,
      seed: () => NatarajState(currentCard: _card()),
      setUp: () {
        when(() => keys.call()).thenAnswer((_) async => const Right(kSigningKeys));
        when(() => publish.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('offline')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.up)),
      expect: () => [],
      verify: (_) {
        verifyNever(() => record.call(any()));
      },
    );

    blocTest<NatarajBloc, NatarajState>(
      'right (draft): a successful save marks drafted and advances',
      build: build,
      seed: () => NatarajState(currentCard: _card()),
      setUp: () {
        when(() => saveDraft.call(any())).thenAnswer((_) async => Right(DraftEntity(
              draftId: 'd1',
              content: 'x',
              eTagRefs: const [],
              pTagRefs: const [],
              tTags: const [],
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            )));
        when(() => next.call(any()))
            .thenAnswer((_) async => Right(_card(signature: 'nxt')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.right)),
      expect: () => [
        isA<NatarajState>().having((s) => s.currentCard?.signature, 'card', 'nxt'),
      ],
      verify: (_) {
        verify(() => record.call(any(
              that: isA<RecordNatarajSwipeInput>()
                  .having((i) => i.status, 'status', NatarajCardStatus.drafted),
            ))).called(1);
      },
    );

    blocTest<NatarajBloc, NatarajState>(
      'right (draft): a save failure aborts before marking or advancing',
      build: build,
      seed: () => NatarajState(currentCard: _card()),
      setUp: () {
        when(() => saveDraft.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('disk full')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.right)),
      expect: () => [],
      verify: (_) {
        verifyNever(() => record.call(any()));
      },
    );

    blocTest<NatarajBloc, NatarajState>(
      'advancing to a real next card requests loadMore in the background',
      build: build,
      seed: () => NatarajState(currentCard: _card()),
      setUp: () {
        when(() => next.call(any()))
            .thenAnswer((_) async => Right(_card(signature: 'nxt')));
      },
      act: (bloc) => bloc.add(const NatarajEvent.swipeCard(NatarajDirection.left)),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(() => generator.fillBuffer(
              manasIds: any(named: 'manasIds'),
              count: any(named: 'count'),
            )).called(greaterThanOrEqualTo(1));
      },
    );
  });
}
