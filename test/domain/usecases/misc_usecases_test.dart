// Bundles the remaining trivial (single-repository-call) domain use cases,
// each 3-15 lines in their own source file, that don't warrant a dedicated
// test file of their own. Same pure-delegation testing style as the other
// files in this directory.
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/entities/onboarding/onboarding_interest_entity.dart';
import 'package:uniun/domain/entities/relay/relay_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/repositories/deleted_note_repository.dart';
import 'package:uniun/domain/repositories/group_repository.dart';
import 'package:uniun/domain/repositories/relay_repository.dart';
import 'package:uniun/domain/repositories/share_repository.dart';
import 'package:uniun/domain/repositories/source_label_repository.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';
import 'package:uniun/domain/usecases/deleted_note_usecases.dart';
import 'package:uniun/domain/usecases/delete_relay_usecase.dart';
import 'package:uniun/domain/usecases/get_group_by_id_usecase.dart';
import 'package:uniun/domain/usecases/get_groups_usecase.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/onboarding_usecases.dart';
import 'package:uniun/domain/usecases/save_group_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';
import 'package:uniun/domain/usecases/share_usecases.dart';
import 'package:uniun/domain/usecases/source_label_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MockRelayRepository extends Mock implements RelayRepository {}

class _MockGroupRepository extends Mock implements GroupRepository {}

class _MockSourceLabelRepository extends Mock
    implements SourceLabelRepository {}

class _MockShareRepository extends Mock implements ShareRepository {}

class _MockUniunRepository extends Mock implements UniunRepository {}

class _MockDeletedNoteRepository extends Mock
    implements DeletedNoteRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(aRelay());
  });

  group('SaveRelayUseCase', () {
    test('trims the url and saves a read/write relay defaulting to '
        'disconnected', () async {
      final repo = _MockRelayRepository();
      when(() => repo.save(any())).thenAnswer(
          (i) async => Right(i.positionalArguments.first as RelayEntity));

      final result = await SaveRelayUseCase(repo).call('  wss://relay.example  ');

      expect(result.isRight(), isTrue);
      final captured = verify(() => repo.save(captureAny())).captured.single as RelayEntity;
      expect(captured.url, 'wss://relay.example');
      expect(captured.read, isTrue);
      expect(captured.write, isTrue);
      expect(captured.status, RelayStatus.disconnected);
    });
  });

  test('GetRelaysUseCase delegates to getAll', () async {
    final repo = _MockRelayRepository();
    when(() => repo.getAll()).thenAnswer((_) async => Right([aRelay()]));

    final result = await GetRelaysUseCase(repo).call();

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('DeleteRelayUseCase trims the url before deleting', () async {
    final repo = _MockRelayRepository();
    when(() => repo.delete('wss://relay.example')).thenAnswer((_) async => const Right(unit));

    final result = await DeleteRelayUseCase(repo).call('  wss://relay.example  ');

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => repo.delete('wss://relay.example')).called(1);
  });

  test('SaveGroupUseCase delegates to saveGroup', () async {
    final repo = _MockGroupRepository();
    final group = aGroup();
    when(() => repo.saveGroup(group)).thenAnswer((_) async => Right(group));

    final result = await SaveGroupUseCase(repo).call(group);

    expect(result, Right<Failure, GroupEntity>(group));
  });

  test('GetGroupsUseCase delegates to getGroups', () async {
    final repo = _MockGroupRepository();
    when(() => repo.getGroups()).thenAnswer((_) async => Right([aGroup()]));

    final result = await GetGroupsUseCase(repo).call();

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('GetGroupByIdUseCase delegates to getGroupById', () async {
    final repo = _MockGroupRepository();
    when(() => repo.getGroupById('g1')).thenAnswer((_) async => Right(aGroup(groupId: 'g1')));

    await GetGroupByIdUseCase(repo).call('g1');

    verify(() => repo.getGroupById('g1')).called(1);
  });

  test('DeleteNoteUseCase delegates to deleteNote', () async {
    final repo = _MockDeletedNoteRepository();
    when(() => repo.deleteNote('n1')).thenAnswer((_) async => const Right(unit));

    final result = await DeleteNoteUseCase(repo).call('n1');

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('ResolveSourceLabelsUseCase delegates to resolveMany', () async {
    final repo = _MockSourceLabelRepository();
    const items = [(eventId: 'n1', groupId: 'g1', privateGroupId: null)];
    when(() => repo.resolveMany(items)).thenAnswer((_) async => {'n1': '#g1'});

    final result = await ResolveSourceLabelsUseCase(repo).call(items);

    expect(result, {'n1': '#g1'});
  });

  test('ShareNoteUseCase delegates to shareNote', () async {
    final repo = _MockShareRepository();
    final input = ShareNoteInput(source: aNote(), destination: const ShareDestination.feed());
    when(() => repo.shareNote(input)).thenAnswer((_) async => const Right(unit));

    final result = await ShareNoteUseCase(repo).call(input);

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('GetOnboardingInterestsUseCase delegates to getOnboardingInterests',
      () async {
    final repo = _MockUniunRepository();
    when(() => repo.getOnboardingInterests()).thenAnswer((_) async => const Right([
          OnboardingInterestEntity(id: 1, name: 'Tech', pubkeyHex: 'pk'),
        ]));

    final result = await GetOnboardingInterestsUseCase(repo).call();

    expect(result.getOrElse(() => []), hasLength(1));
  });
}
