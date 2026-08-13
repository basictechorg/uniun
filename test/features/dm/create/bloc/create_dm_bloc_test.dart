import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/repositories/relay_repository.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/features/dm/create/bloc/create_dm_bloc.dart';

import '../../../../_helpers/fixtures.dart';

class _MockRelayRepository extends Mock implements RelayRepository {}

class _MockCreateDmConversation extends Mock
    implements CreateDmConversationUseCase {}

/// Covers: CreateDmBloc's relay loading (success sorts urls, failure
/// surfaces an error), and submit's validation chain (empty pubkey,
/// malformed pubkey, relay fallback to the loaded list when none are
/// explicitly selected, success, repository failure, and a FormatException
/// escaping normalizeNostrPubkey).
void main() {
  late _MockRelayRepository relayRepo;
  late _MockCreateDmConversation createDmConversation;

  CreateDmBloc build() => CreateDmBloc(relayRepo, createDmConversation);

  setUpAll(() {
    registerFallbackValue(CreateDmParams(otherPubkey: '', relays: const []));
  });

  setUp(() {
    relayRepo = _MockRelayRepository();
    createDmConversation = _MockCreateDmConversation();
  });

  group('LoadRelaysEvent', () {
    blocTest<CreateDmBloc, CreateDmState>(
      'loads and sorts the relay urls',
      build: () {
        when(() => relayRepo.getAll())
            .thenAnswer((_) async => Right([aRelay(url: 'wss://z.example'), aRelay(url: 'wss://a.example')]));
        return build();
      },
      act: (b) => b.add(LoadRelaysEvent()),
      expect: () => [
        isA<CreateDmState>().having((s) => s.isLoadingRelays, 'isLoadingRelays', true),
        isA<CreateDmState>()
            .having((s) => s.isLoadingRelays, 'isLoadingRelays', false)
            .having((s) => s.availableRelays, 'availableRelays', ['wss://a.example', 'wss://z.example']),
      ],
    );

    blocTest<CreateDmBloc, CreateDmState>(
      'a repository failure surfaces an error',
      build: () {
        when(() => relayRepo.getAll())
            .thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      act: (b) => b.add(LoadRelaysEvent()),
      verify: (b) {
        expect(b.state.errorMessage, isNotNull);
        expect(b.state.availableRelays, isEmpty);
      },
    );
  });

  // `_onSubmit`'s `if (resolvedPubkey.isEmpty)` guard right after
  // normalizeNostrPubkey() is unreachable: that function either throws
  // FormatException on invalid input or returns a non-empty 64-char hex
  // string — it never returns empty. Left uncovered rather than faking a
  // return value the real function can't produce.
  group('SubmitDmEvent', () {
    blocTest<CreateDmBloc, CreateDmState>(
      'an empty pubkey surfaces an error, then clears it, without calling '
      'the use case',
      build: build,
      act: (b) => b.add(SubmitDmEvent(otherPubkey: '   ', selectedRelays: const [])),
      expect: () => [
        isA<CreateDmState>().having((s) => s.errorMessage, 'errorMessage', isNotNull),
        isA<CreateDmState>().having((s) => s.errorMessage, 'errorMessage', isNull),
      ],
      verify: (_) {
        verifyZeroInteractions(createDmConversation);
      },
    );

    blocTest<CreateDmBloc, CreateDmState>(
      'a malformed pubkey surfaces an error, then clears it',
      build: build,
      act: (b) => b.add(SubmitDmEvent(otherPubkey: 'not-a-valid-key', selectedRelays: const [])),
      verify: (b) {
        expect(b.state.isSubmitting, isFalse);
        expect(b.state.errorMessage, isNull); // cleared by the trailing emit
        verifyZeroInteractions(createDmConversation);
      },
    );

    blocTest<CreateDmBloc, CreateDmState>(
      'falls back to the loaded relay list when none are explicitly '
      'selected',
      build: () {
        when(() => createDmConversation.call(any()))
            .thenAnswer((_) async => Right(aDmConversation()));
        return build();
      },
      seed: () => const CreateDmState(availableRelays: ['wss://fallback.example']),
      act: (b) => b.add(SubmitDmEvent(otherPubkey: kSampleTargetPubkeyHex, selectedRelays: const [])),
      verify: (_) {
        final params = verify(() => createDmConversation.call(captureAny())).captured.single as CreateDmParams;
        expect(params.relays, ['wss://fallback.example']);
      },
    );

    blocTest<CreateDmBloc, CreateDmState>(
      'uses the explicitly selected relays over the fallback list when '
      'both are present',
      build: () {
        when(() => createDmConversation.call(any()))
            .thenAnswer((_) async => Right(aDmConversation()));
        return build();
      },
      seed: () => const CreateDmState(availableRelays: ['wss://fallback.example']),
      act: (b) => b.add(SubmitDmEvent(
        otherPubkey: kSampleTargetPubkeyHex,
        selectedRelays: const ['wss://chosen.example'],
      )),
      verify: (_) {
        final params = verify(() => createDmConversation.call(captureAny())).captured.single as CreateDmParams;
        expect(params.relays, ['wss://chosen.example']);
      },
    );

    blocTest<CreateDmBloc, CreateDmState>(
      'success sets isSuccess',
      build: () {
        when(() => createDmConversation.call(any()))
            .thenAnswer((_) async => Right(aDmConversation()));
        return build();
      },
      act: (b) => b.add(SubmitDmEvent(otherPubkey: kSampleTargetPubkeyHex, selectedRelays: const [])),
      verify: (b) {
        expect(b.state.isSuccess, isTrue);
        expect(b.state.isSubmitting, isFalse);
      },
    );

    blocTest<CreateDmBloc, CreateDmState>(
      'a repository failure surfaces an error and does not set isSuccess',
      build: () {
        when(() => createDmConversation.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('isar write failed')));
        return build();
      },
      act: (b) => b.add(SubmitDmEvent(otherPubkey: kSampleTargetPubkeyHex, selectedRelays: const [])),
      verify: (b) {
        expect(b.state.isSuccess, isFalse);
        expect(b.state.errorMessage, isNotNull);
      },
    );

    blocTest<CreateDmBloc, CreateDmState>(
      'an unexpected (non-FormatException) throw from the use case is '
      'caught by the generic handler',
      build: () {
        when(() => createDmConversation.call(any())).thenThrow(Exception('isar closed'));
        return build();
      },
      act: (b) => b.add(SubmitDmEvent(otherPubkey: kSampleTargetPubkeyHex, selectedRelays: const [])),
      verify: (b) {
        expect(b.state.isSubmitting, isFalse);
        expect(b.state.errorMessage, contains('isar closed'));
      },
    );
  });

  group('LoadRelaysEvent error handling', () {
    blocTest<CreateDmBloc, CreateDmState>(
      'an unexpected throw from the repository is caught by the generic '
      'handler',
      build: () {
        when(() => relayRepo.getAll()).thenThrow(Exception('isar closed'));
        return build();
      },
      act: (b) => b.add(LoadRelaysEvent()),
      verify: (b) {
        expect(b.state.isLoadingRelays, isFalse);
        expect(b.state.errorMessage, contains('isar closed'));
      },
    );
  });
}
