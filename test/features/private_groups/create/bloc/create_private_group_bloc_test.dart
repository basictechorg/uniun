import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/private_groups/create/bloc/create_private_group_bloc.dart';

class _MockCreatePrivateGroup extends Mock
    implements CreatePrivateGroupUsecase {}

class _MockGetActiveUserKeys extends Mock
    implements GetActiveUserKeysUseCase {}

/// Covers: CreatePrivateGroupBloc's submit flow — success populates
/// createdGroupId, a missing active user surfaces as an error without
/// calling the use case, and a use-case throw is caught (not rethrown).
void main() {
  late _MockCreatePrivateGroup createGroup;
  late _MockGetActiveUserKeys getKeys;

  CreatePrivateGroupBloc build() => CreatePrivateGroupBloc(createGroup, getKeys);

  setUp(() {
    createGroup = _MockCreatePrivateGroup();
    getKeys = _MockGetActiveUserKeys();
  });

  blocTest<CreatePrivateGroupBloc, CreatePrivateGroupState>(
    'success: emits isSubmitting, then isSuccess with the new group id',
    build: () {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(privkeyHex: 'pk', pubkeyHex: 'author'),
          ));
      when(() => createGroup.execute(
            privkeyHex: 'pk',
            authorPubkey: 'author',
            name: 'Secret',
            description: 'desc',
            relays: ['wss://relay.example'],
          )).thenAnswer((_) async => 'group-1');
      return build();
    },
    act: (b) => b.add(SubmitCreatePrivateGroupEvent(
      name: 'Secret',
      description: 'desc',
      relays: const ['wss://relay.example'],
    )),
    expect: () => [
      isA<CreatePrivateGroupState>().having((s) => s.isSubmitting, 'isSubmitting', true),
      isA<CreatePrivateGroupState>()
          .having((s) => s.isSubmitting, 'isSubmitting', false)
          .having((s) => s.isSuccess, 'isSuccess', true)
          .having((s) => s.createdGroupId, 'createdGroupId', 'group-1'),
    ],
  );

  blocTest<CreatePrivateGroupBloc, CreatePrivateGroupState>(
    'no active user: surfaces an error without calling the use case',
    build: () {
      when(() => getKeys.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
      return build();
    },
    act: (b) => b.add(SubmitCreatePrivateGroupEvent(
      name: 'Secret',
      description: 'desc',
      relays: const [],
    )),
    expect: () => [
      isA<CreatePrivateGroupState>().having((s) => s.isSubmitting, 'isSubmitting', true),
      isA<CreatePrivateGroupState>()
          .having((s) => s.isSubmitting, 'isSubmitting', false)
          .having((s) => s.isSuccess, 'isSuccess', false)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
    verify: (_) {
      verifyZeroInteractions(createGroup);
    },
  );

  blocTest<CreatePrivateGroupBloc, CreatePrivateGroupState>(
    'a use-case throw is caught, not rethrown',
    build: () {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(privkeyHex: 'pk', pubkeyHex: 'author'),
          ));
      when(() => createGroup.execute(
            privkeyHex: any(named: 'privkeyHex'),
            authorPubkey: any(named: 'authorPubkey'),
            name: any(named: 'name'),
            description: any(named: 'description'),
            relays: any(named: 'relays'),
          )).thenThrow(Exception('MLS init failed'));
      return build();
    },
    act: (b) => b.add(SubmitCreatePrivateGroupEvent(
      name: 'Secret',
      description: 'desc',
      relays: const [],
    )),
    expect: () => [
      isA<CreatePrivateGroupState>().having((s) => s.isSubmitting, 'isSubmitting', true),
      isA<CreatePrivateGroupState>()
          .having((s) => s.isSubmitting, 'isSubmitting', false)
          .having((s) => s.errorMessage, 'errorMessage', contains('MLS init failed')),
    ],
  );
}
