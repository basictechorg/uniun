import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';
import 'package:uniun/domain/repositories/gana_repository.dart';
import 'package:uniun/domain/repositories/gana_run_repository.dart';
import 'package:uniun/domain/usecases/gana_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MockGanaRepository extends Mock implements GanaRepository {}

class _MockGanaRunRepository extends Mock implements GanaRunRepository {}

GanaRunEntity _aRun({String ganaId = 'gana-1'}) => GanaRunEntity(
      runId: 'run-1',
      ganaId: ganaId,
      startedAt: DateTime(2026, 1, 1),
      status: GanaRunStatus.succeeded,
    );

void main() {
  late _MockGanaRepository ganaRepo;
  late _MockGanaRunRepository runRepo;

  setUpAll(() {
    registerFallbackValue(aGana());
    registerFallbackValue(_aRun());
  });

  setUp(() {
    ganaRepo = _MockGanaRepository();
    runRepo = _MockGanaRunRepository();
  });

  test('UpsertGanaUseCase delegates to upsertGana', () async {
    final gana = aGana();
    when(() => ganaRepo.upsertGana(gana)).thenAnswer((_) async => Right(gana));

    final result = await UpsertGanaUseCase(ganaRepo).call(gana);

    expect(result, Right(gana));
  });

  test('GetGanasUseCase delegates to getGanas', () async {
    when(() => ganaRepo.getGanas()).thenAnswer((_) async => Right([aGana()]));

    final result = await GetGanasUseCase(ganaRepo).call();

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('GetEnabledGanasUseCase delegates to getEnabledGanas', () async {
    when(() => ganaRepo.getEnabledGanas()).thenAnswer((_) async => Right([aGana()]));

    await GetEnabledGanasUseCase(ganaRepo).call();

    verify(() => ganaRepo.getEnabledGanas()).called(1);
  });

  test('GetGanaByIdUseCase delegates to getGanaById', () async {
    when(() => ganaRepo.getGanaById('gana-1')).thenAnswer((_) async => Right(aGana()));

    await GetGanaByIdUseCase(ganaRepo).call('gana-1');

    verify(() => ganaRepo.getGanaById('gana-1')).called(1);
  });

  test('DeleteGanaUseCase delegates to deleteGana', () async {
    when(() => ganaRepo.deleteGana('gana-1')).thenAnswer((_) async => const Right(unit));

    final result = await DeleteGanaUseCase(ganaRepo).call('gana-1');

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('SetGanaEnabledUseCase forwards ganaId + enabled', () async {
    when(() => ganaRepo.setEnabled('gana-1', true)).thenAnswer((_) async => const Right(unit));

    await SetGanaEnabledUseCase(ganaRepo).call(const GanaToggleInput('gana-1', true));

    verify(() => ganaRepo.setEnabled('gana-1', true)).called(1);
  });

  test('AdvanceGanaCursorUseCase forwards every field', () async {
    final lastRunAt = DateTime(2026, 2, 1);
    final lastProcessedCreated = DateTime(2026, 1, 30);
    when(() => ganaRepo.advanceCursor(
          ganaId: 'gana-1',
          lastProcessedEventId: 'evt-1',
          lastProcessedCreated: lastProcessedCreated,
          lastRunAt: lastRunAt,
        )).thenAnswer((_) async => const Right(unit));

    await AdvanceGanaCursorUseCase(ganaRepo).call(GanaCursorAdvanceInput(
      ganaId: 'gana-1',
      lastProcessedEventId: 'evt-1',
      lastProcessedCreated: lastProcessedCreated,
      lastRunAt: lastRunAt,
    ));

    verify(() => ganaRepo.advanceCursor(
          ganaId: 'gana-1',
          lastProcessedEventId: 'evt-1',
          lastProcessedCreated: lastProcessedCreated,
          lastRunAt: lastRunAt,
        )).called(1);
  });

  test('LogGanaRunUseCase delegates to logRun', () async {
    final run = _aRun();
    when(() => runRepo.logRun(run)).thenAnswer((_) async => const Right(unit));

    final result = await LogGanaRunUseCase(runRepo).call(run);

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('GetGanaRunsUseCase delegates to getRunsFor', () async {
    when(() => runRepo.getRunsFor('gana-1')).thenAnswer((_) async => Right([_aRun()]));

    await GetGanaRunsUseCase(runRepo).call('gana-1');

    verify(() => runRepo.getRunsFor('gana-1')).called(1);
  });

  test('GetGanaOutputEventIdsUseCase delegates to getOutputEventIdsFor',
      () async {
    when(() => runRepo.getOutputEventIdsFor('gana-1'))
        .thenAnswer((_) async => Right({'evt-1'}));

    final result = await GetGanaOutputEventIdsUseCase(runRepo).call('gana-1');

    expect(result.getOrElse(() => {}), {'evt-1'});
  });

  test('PruneGanaRunsUseCase delegates to pruneOldRuns', () async {
    when(() => runRepo.pruneOldRuns()).thenAnswer((_) async => const Right(unit));

    final result = await PruneGanaRunsUseCase(runRepo).call();

    expect(result, const Right<Failure, Unit>(unit));
  });
}
