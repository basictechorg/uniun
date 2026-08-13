import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/private_groups/join/bloc/join_private_group_bloc.dart';

class _MockJoinPrivateGroup extends Mock implements JoinPrivateGroupUsecase {}

class _MockGetActiveUserKeys extends Mock
    implements GetActiveUserKeysUseCase {}

/// Covers: JoinPrivateGroupBloc's submit flow — success, missing active
/// user short-circuits before the use case, and a use-case throw is caught.
void main() {
  late _MockJoinPrivateGroup joinGroup;
  late _MockGetActiveUserKeys getKeys;

  JoinPrivateGroupBloc build() => JoinPrivateGroupBloc(joinGroup, getKeys);

  setUp(() {
    joinGroup = _MockJoinPrivateGroup();
    getKeys = _MockGetActiveUserKeys();
  });

  blocTest<JoinPrivateGroupBloc, JoinPrivateGroupState>(
    'success: emits isSubmitting then isSuccess',
    build: () {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(privkeyHex: 'pk', pubkeyHex: 'author'),
          ));
      when(() => joinGroup.execute(
            groupId: 'g1',
            authorPubkey: 'author',
            privkeyHex: 'pk',
            relays: ['wss://relay.example'],
          )).thenAnswer((_) async {});
      return build();
    },
    act: (b) => b.add(SubmitJoinPrivateGroupEvent(
      groupId: 'g1',
      relays: const ['wss://relay.example'],
    )),
    expect: () => [
      isA<JoinPrivateGroupState>().having((s) => s.isSubmitting, 'isSubmitting', true),
      isA<JoinPrivateGroupState>()
          .having((s) => s.isSubmitting, 'isSubmitting', false)
          .having((s) => s.isSuccess, 'isSuccess', true),
    ],
  );

  blocTest<JoinPrivateGroupBloc, JoinPrivateGroupState>(
    'no active user: surfaces an error without calling the use case',
    build: () {
      when(() => getKeys.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('no active user')));
      return build();
    },
    act: (b) => b.add(SubmitJoinPrivateGroupEvent(groupId: 'g1', relays: const [])),
    expect: () => [
      isA<JoinPrivateGroupState>().having((s) => s.isSubmitting, 'isSubmitting', true),
      isA<JoinPrivateGroupState>()
          .having((s) => s.isSubmitting, 'isSubmitting', false)
          .having((s) => s.isSuccess, 'isSuccess', false)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
    verify: (_) {
      verifyZeroInteractions(joinGroup);
    },
  );

  blocTest<JoinPrivateGroupBloc, JoinPrivateGroupState>(
    'a use-case throw is caught, not rethrown',
    build: () {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(privkeyHex: 'pk', pubkeyHex: 'author'),
          ));
      when(() => joinGroup.execute(
            groupId: any(named: 'groupId'),
            authorPubkey: any(named: 'authorPubkey'),
            privkeyHex: any(named: 'privkeyHex'),
            relays: any(named: 'relays'),
          )).thenThrow(Exception('key package request failed'));
      return build();
    },
    act: (b) => b.add(SubmitJoinPrivateGroupEvent(groupId: 'g1', relays: const [])),
    expect: () => [
      isA<JoinPrivateGroupState>().having((s) => s.isSubmitting, 'isSubmitting', true),
      isA<JoinPrivateGroupState>()
          .having((s) => s.isSubmitting, 'isSubmitting', false)
          .having((s) => s.errorMessage, 'errorMessage', contains('key package request failed')),
    ],
  );
}
