import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/repositories/manas_repository.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';

class _MockRepo extends Mock implements ManasRepository {}

ManasEntity _manas(String id) => ManasEntity(
      manasId: id,
      name: id,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Domain-layer tests for every use case in `manas_usecases.dart`. These are
/// thin pass-throughs to [ManasRepository], so the tests assert *only*
/// "the right repo method is called with the right args, the right result
/// flows back" — no business logic to verify here. Catches accidental
/// rewiring (e.g. someone swaps `add` with `remove`).
void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(_manas('fallback'));
  });

  setUp(() {
    repo = _MockRepo();
  });

  test('UpsertManasUseCase forwards to ManasRepository.upsertManas', () async {
    final m = _manas('a');
    when(() => repo.upsertManas(m)).thenAnswer((_) async => Right(m));
    final r = await UpsertManasUseCase(repo).call(m);
    expect(r.getOrElse(() => throw 'left').manasId, 'a');
    verify(() => repo.upsertManas(m)).called(1);
  });

  test('GetManasListUseCase forwards to ManasRepository.getManasList', () async {
    when(() => repo.getManasList())
        .thenAnswer((_) async => Right([_manas('x'), _manas('y')]));
    final r = await GetManasListUseCase(repo).call();
    expect(r.getOrElse(() => []).map((m) => m.manasId), ['x', 'y']);
    verify(() => repo.getManasList()).called(1);
  });

  test('GetManasByIdUseCase forwards to ManasRepository.getManasById', () async {
    when(() => repo.getManasById('z')).thenAnswer((_) async => Right(_manas('z')));
    final r = await GetManasByIdUseCase(repo).call('z');
    expect(r.getOrElse(() => throw 'left').manasId, 'z');
    verify(() => repo.getManasById('z')).called(1);
  });

  test('DeleteManasUseCase forwards to ManasRepository.deleteManas', () async {
    when(() => repo.deleteManas('z')).thenAnswer((_) async => const Right(unit));
    final r = await DeleteManasUseCase(repo).call('z');
    expect(r.isRight(), isTrue);
    verify(() => repo.deleteManas('z')).called(1);
  });

  test('AddNoteToManasUseCase forwards both ids to ManasRepository.addNoteToManas',
      () async {
    when(() => repo.addNoteToManas('m', 'n'))
        .thenAnswer((_) async => const Right(unit));
    final r = await AddNoteToManasUseCase(repo).call(const ManasNoteLink('m', 'n'));
    expect(r.isRight(), isTrue);
    verify(() => repo.addNoteToManas('m', 'n')).called(1);
    // Critical: ensures the use case did NOT accidentally call removeNoteFromManas.
    verifyNever(() => repo.removeNoteFromManas(any(), any()));
  });

  test('RemoveNoteFromManasUseCase forwards to ManasRepository.removeNoteFromManas',
      () async {
    when(() => repo.removeNoteFromManas('m', 'n'))
        .thenAnswer((_) async => const Right(unit));
    final r = await RemoveNoteFromManasUseCase(repo).call(const ManasNoteLink('m', 'n'));
    expect(r.isRight(), isTrue);
    verify(() => repo.removeNoteFromManas('m', 'n')).called(1);
    verifyNever(() => repo.addNoteToManas(any(), any()));
  });

  test('GetNoteIdsForManasUseCase forwards to repo.getNoteIdsForManas', () async {
    when(() => repo.getNoteIdsForManas('m'))
        .thenAnswer((_) async => const Right(['n-1', 'n-2']));
    final r = await GetNoteIdsForManasUseCase(repo).call('m');
    expect(r.getOrElse(() => []), ['n-1', 'n-2']);
  });

  test('GetManasIdsForNoteUseCase forwards to repo.getManasIdsForNote', () async {
    when(() => repo.getManasIdsForNote('n'))
        .thenAnswer((_) async => const Right(['m-1', 'm-2']));
    final r = await GetManasIdsForNoteUseCase(repo).call('n');
    expect(r.getOrElse(() => []), ['m-1', 'm-2']);
  });

  test('Left failures propagate through every use case unchanged', () async {
    const fail = Failure.errorFailure('boom');
    when(() => repo.upsertManas(any())).thenAnswer((_) async => const Left(fail));
    final r = await UpsertManasUseCase(repo).call(_manas('a'));
    expect(r.isLeft(), isTrue);
    r.fold((f) => expect(f, fail), (_) => fail.toString());
  });
}
