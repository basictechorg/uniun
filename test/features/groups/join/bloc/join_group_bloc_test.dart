import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/usecases/save_group_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';
import 'package:uniun/features/groups/join/bloc/join_group_bloc.dart';

import '../../../../_helpers/fixtures.dart';

class _MockSaveRelay extends Mock implements SaveRelayUseCase {}

class _MockSaveGroup extends Mock implements SaveGroupUseCase {}

const _validGroupId =
    '1111111111111111111111111111111111111111111111111111111111111111';

/// Covers: JoinGroupBloc's group-id validation (must be 64-hex),
/// at-least-one-relay guard, relay dedup/trim, saving every relay before
/// the group (aborting on the first relay-save failure), and both outcomes
/// of the group save itself.
void main() {
  late _MockSaveRelay saveRelay;
  late _MockSaveGroup saveGroup;

  JoinGroupBloc build() => JoinGroupBloc(saveRelay, saveGroup);

  setUpAll(() {
    registerFallbackValue(aGroup());
  });

  setUp(() {
    saveRelay = _MockSaveRelay();
    saveGroup = _MockSaveGroup();
  });

  blocTest<JoinGroupBloc, JoinGroupState>(
    'an invalid (non-64-hex) group id is rejected before touching any '
    'use case',
    build: build,
    act: (b) => b.add(const SubmitJoinGroupEvent(
      groupId: 'not-hex',
      selectedRelays: ['wss://r'],
      groupName: 'G',
    )),
    expect: () => [
      isA<JoinGroupState>().having((s) => s.error, 'error', JoinGroupError.invalidId),
    ],
    verify: (_) {
      verifyZeroInteractions(saveRelay);
      verifyZeroInteractions(saveGroup);
    },
  );

  blocTest<JoinGroupBloc, JoinGroupState>(
    'no relays selected after trimming/dedup is rejected',
    build: build,
    act: (b) => b.add(const SubmitJoinGroupEvent(
      groupId: _validGroupId,
      selectedRelays: ['   ', ''],
      groupName: 'G',
    )),
    expect: () => [
      isA<JoinGroupState>().having((s) => s.error, 'error', JoinGroupError.noRelay),
    ],
  );

  blocTest<JoinGroupBloc, JoinGroupState>(
    'relays are trimmed and deduplicated before saving',
    build: () {
      when(() => saveRelay.call(any())).thenAnswer((_) async => Right(aRelay()));
      when(() => saveGroup.call(any())).thenAnswer((_) async => Right(aGroup()));
      return build();
    },
    act: (b) => b.add(const SubmitJoinGroupEvent(
      groupId: _validGroupId,
      selectedRelays: [' wss://r.example ', 'wss://r.example', 'wss://r.example'],
      groupName: 'G',
    )),
    verify: (_) {
      verify(() => saveRelay.call('wss://r.example')).called(1);
    },
  );

  blocTest<JoinGroupBloc, JoinGroupState>(
    'aborts on the first relay-save failure without saving the group',
    build: () {
      when(() => saveRelay.call(any()))
          .thenAnswer((_) async => const Left(Failure.errorFailure('isar write failed')));
      return build();
    },
    act: (b) => b.add(const SubmitJoinGroupEvent(
      groupId: _validGroupId,
      selectedRelays: ['wss://r'],
      groupName: 'G',
    )),
    expect: () => [
      isA<JoinGroupState>().having((s) => s.isSubmitting, 'isSubmitting', true),
      isA<JoinGroupState>()
          .having((s) => s.isSubmitting, 'isSubmitting', false)
          .having((s) => s.error, 'error', JoinGroupError.relaySaveFailed),
    ],
    verify: (_) {
      verifyZeroInteractions(saveGroup);
    },
  );

  blocTest<JoinGroupBloc, JoinGroupState>(
    'saves the group with the trimmed name once every relay succeeds',
    build: () {
      when(() => saveRelay.call(any())).thenAnswer((_) async => Right(aRelay()));
      when(() => saveGroup.call(any())).thenAnswer((i) async => Right(i.positionalArguments.first as GroupEntity));
      return build();
    },
    act: (b) => b.add(const SubmitJoinGroupEvent(
      groupId: _validGroupId,
      selectedRelays: ['wss://r'],
      groupName: '  My Group  ',
    )),
    verify: (b) {
      expect(b.state.isSuccess, isTrue);
      expect(b.state.error, isNull);
      final saved = verify(() => saveGroup.call(captureAny())).captured.single as GroupEntity;
      expect(saved.groupId, _validGroupId);
      expect(saved.name, 'My Group');
    },
  );

  blocTest<JoinGroupBloc, JoinGroupState>(
    'a group-save failure surfaces saveFailed',
    build: () {
      when(() => saveRelay.call(any())).thenAnswer((_) async => Right(aRelay()));
      when(() => saveGroup.call(any()))
          .thenAnswer((_) async => const Left(Failure.errorFailure('isar write failed')));
      return build();
    },
    act: (b) => b.add(const SubmitJoinGroupEvent(
      groupId: _validGroupId,
      selectedRelays: ['wss://r'],
      groupName: 'G',
    )),
    verify: (b) {
      expect(b.state.isSuccess, isFalse);
      expect(b.state.error, JoinGroupError.saveFailed);
    },
  );
}
