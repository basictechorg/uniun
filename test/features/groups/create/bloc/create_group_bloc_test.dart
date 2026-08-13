import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/usecases/create_group_usecase.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/groups/create/bloc/create_group_bloc.dart';

import '../../../../_helpers/fixtures.dart';

class _MockGetRelays extends Mock implements GetRelaysUseCase {}

class _MockGetActiveUser extends Mock implements GetActiveUserUseCase {}

class _MockCreateGroup extends Mock implements CreateGroupUseCase {}

/// Covers: CreateGroupBloc's relay loading, submit's validation chain
/// (name length bounds, at-least-one-relay), the missing-active-user
/// guard, nsec decoding (including a decode failure), and success/failure
/// from CreateGroupUseCase.
void main() {
  late _MockGetRelays getRelays;
  late _MockGetActiveUser getActiveUser;
  late _MockCreateGroup createGroup;

  CreateGroupBloc build() => CreateGroupBloc(getRelays, getActiveUser, createGroup);

  setUpAll(() {
    registerFallbackValue(const CreateGroupInput(
      name: '',
      about: '',
      picture: '',
      relays: [],
      privateKey: '',
    ));
  });

  setUp(() {
    getRelays = _MockGetRelays();
    getActiveUser = _MockGetActiveUser();
    createGroup = _MockCreateGroup();
  });

  group('LoadRelaysEvent', () {
    blocTest<CreateGroupBloc, CreateGroupState>(
      'loads relay urls on success',
      build: () {
        when(() => getRelays.call()).thenAnswer((_) async => Right([aRelay(url: 'wss://relay.example')]));
        return build();
      },
      act: (b) => b.add(LoadRelaysEvent()),
      expect: () => [
        isA<CreateGroupState>().having((s) => s.isLoadingRelays, 'isLoadingRelays', true),
        isA<CreateGroupState>()
            .having((s) => s.isLoadingRelays, 'isLoadingRelays', false)
            .having((s) => s.availableRelays, 'availableRelays', ['wss://relay.example']),
      ],
    );

    blocTest<CreateGroupBloc, CreateGroupState>(
      'a repository failure surfaces an error',
      build: () {
        when(() => getRelays.call()).thenAnswer((_) async => const Left(Failure.errorFailure('boom')));
        return build();
      },
      act: (b) => b.add(LoadRelaysEvent()),
      verify: (b) {
        expect(b.state.errorMessage, isNotNull);
      },
    );
  });

  group('SubmitGroupEvent validation', () {
    blocTest<CreateGroupBloc, CreateGroupState>(
      'a name under 3 characters is rejected',
      build: build,
      act: (b) => b.add(SubmitGroupEvent(name: 'ab', about: '', picture: '', selectedRelays: const ['wss://r'])),
      verify: (b) {
        expect(b.state.errorMessage, contains('at least 3'));
        expect(b.state.isSubmitting, isFalse);
      },
    );

    blocTest<CreateGroupBloc, CreateGroupState>(
      'a name over 30 characters is rejected',
      build: build,
      act: (b) => b.add(SubmitGroupEvent(
        name: 'x' * 31,
        about: '',
        picture: '',
        selectedRelays: const ['wss://r'],
      )),
      verify: (b) {
        expect(b.state.errorMessage, contains('exceed 30'));
      },
    );

    blocTest<CreateGroupBloc, CreateGroupState>(
      'no relays selected is rejected',
      build: build,
      act: (b) => b.add(SubmitGroupEvent(name: 'Valid Name', about: '', picture: '', selectedRelays: const [])),
      verify: (b) {
        expect(b.state.errorMessage, contains('relay'));
      },
    );
  });

  group('SubmitGroupEvent', () {
    blocTest<CreateGroupBloc, CreateGroupState>(
      'no active user surfaces an error without calling CreateGroupUseCase',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
        return build();
      },
      act: (b) => b.add(SubmitGroupEvent(
        name: 'Valid Name',
        about: '',
        picture: '',
        selectedRelays: const ['wss://r'],
      )),
      verify: (b) {
        expect(b.state.errorMessage, isNotNull);
        verifyZeroInteractions(createGroup);
      },
    );

    blocTest<CreateGroupBloc, CreateGroupState>(
      'a raw hex nsec is used as-is (no decode step)',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(nsec: kTestPrivHex)));
        when(() => createGroup.call(any())).thenAnswer((_) async => Right(aGroup()));
        return build();
      },
      act: (b) => b.add(SubmitGroupEvent(
        name: 'Valid Name',
        about: 'about',
        picture: '',
        selectedRelays: const ['wss://r'],
      )),
      verify: (b) {
        expect(b.state.isSuccess, isTrue);
        final input = verify(() => createGroup.call(captureAny())).captured.single as CreateGroupInput;
        expect(input.privateKey, kTestPrivHex);
      },
    );

    blocTest<CreateGroupBloc, CreateGroupState>(
      'an nsec1-prefixed key is decoded before use',
      build: () {
        when(() => getActiveUser.call())
            .thenAnswer((_) async => Right(aUserKey(nsec: Nip19.encodePrivkey(kTestPrivHex))));
        when(() => createGroup.call(any())).thenAnswer((_) async => Right(aGroup()));
        return build();
      },
      act: (b) => b.add(SubmitGroupEvent(
        name: 'Valid Name',
        about: '',
        picture: '',
        selectedRelays: const ['wss://r'],
      )),
      verify: (_) {
        final input = verify(() => createGroup.call(captureAny())).captured.single as CreateGroupInput;
        expect(input.privateKey, kTestPrivHex);
      },
    );

    blocTest<CreateGroupBloc, CreateGroupState>(
      'an nsec1-prefixed key that fails to decode surfaces a decode error, '
      'never reaching CreateGroupUseCase',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(nsec: 'nsec1not-valid-bech32')));
        return build();
      },
      act: (b) => b.add(SubmitGroupEvent(
        name: 'Valid Name',
        about: '',
        picture: '',
        selectedRelays: const ['wss://r'],
      )),
      verify: (b) {
        expect(b.state.isSubmitting, isFalse);
        expect(b.state.errorMessage, contains('decode'));
        verifyZeroInteractions(createGroup);
      },
    );

    blocTest<CreateGroupBloc, CreateGroupState>(
      'a CreateGroupUseCase failure surfaces its message',
      build: () {
        when(() => getActiveUser.call()).thenAnswer((_) async => Right(aUserKey(nsec: kTestPrivHex)));
        when(() => createGroup.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('relay rejected')));
        return build();
      },
      act: (b) => b.add(SubmitGroupEvent(
        name: 'Valid Name',
        about: '',
        picture: '',
        selectedRelays: const ['wss://r'],
      )),
      verify: (b) {
        expect(b.state.isSuccess, isFalse);
        expect(b.state.errorMessage, isNotNull);
      },
    );
  });
}
