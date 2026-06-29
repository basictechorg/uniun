import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/features/brahma/manas/bloc/manas_list_bloc.dart';

class _MockGetManasList extends Mock implements GetManasListUseCase {}

class _MockDeleteManas extends Mock implements DeleteManasUseCase {}

ManasEntity _manas(String id, {String name = 'm'}) => ManasEntity(
      manasId: id,
      name: name,
      iconName: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Tests for [ManasListBloc]. Uses the industry-standard `bloc_test` +
/// `mocktail` combo. `blocTest()` runs the BLoC, dispatches events, and
/// asserts the emitted state sequence declaratively.
void main() {
  late _MockGetManasList getList;
  late _MockDeleteManas deleteManas;

  setUp(() {
    getList = _MockGetManasList();
    deleteManas = _MockDeleteManas();
  });

  group('ManasListLoadEvent', () {
    blocTest<ManasListBloc, ManasListState>(
      'emits loading → loaded with the use case result',
      build: () {
        when(() => getList.call()).thenAnswer(
          (_) async => Right([_manas('a'), _manas('b')]),
        );
        return ManasListBloc(getList, deleteManas);
      },
      act: (bloc) => bloc.add(const ManasListLoadEvent()),
      verify: (bloc) {
        expect(bloc.state.status, ManasListStatus.loaded);
        expect(bloc.state.manases.map((m) => m.manasId), ['a', 'b']);
        verify(() => getList.call()).called(1);
      },
    );

    blocTest<ManasListBloc, ManasListState>(
      'use case failure → status:error with the failure message',
      build: () {
        when(() => getList.call()).thenAnswer(
          (_) async => const Left(Failure.errorFailure('boom')),
        );
        return ManasListBloc(getList, deleteManas);
      },
      act: (bloc) => bloc.add(const ManasListLoadEvent()),
      verify: (bloc) {
        expect(bloc.state.status, ManasListStatus.error);
        expect(bloc.state.errorMessage, contains('boom'));
      },
    );

    blocTest<ManasListBloc, ManasListState>(
      'empty list → loaded with manases empty (NOT error)',
      build: () {
        when(() => getList.call()).thenAnswer((_) async => const Right([]));
        return ManasListBloc(getList, deleteManas);
      },
      act: (bloc) => bloc.add(const ManasListLoadEvent()),
      verify: (bloc) {
        expect(bloc.state.status, ManasListStatus.loaded);
        expect(bloc.state.manases, isEmpty);
      },
    );
  });

  group('ManasListDeleteEvent', () {
    blocTest<ManasListBloc, ManasListState>(
      'calls delete use case, then auto-reloads via ManasListLoadEvent',
      build: () {
        // Successive list reads: first contains both, second only "b" (after
        // delete). Drives the assertion that the BLoC reloaded after delete.
        final responses = <List<ManasEntity>>[
          [_manas('a'), _manas('b')],
          [_manas('b')],
        ];
        when(() => deleteManas.call(any())).thenAnswer((_) async => const Right(unit));
        when(() => getList.call()).thenAnswer((_) async => Right(responses.removeAt(0)));
        return ManasListBloc(getList, deleteManas);
      },
      act: (bloc) async {
        bloc.add(const ManasListLoadEvent());
        // Let the load finish first so the second load (post-delete) is
        // distinguishable in `verify`.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const ManasListDeleteEvent('a'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        verify(() => deleteManas.call('a')).called(1);
        // 2 loads: the initial one + the post-delete reload.
        verify(() => getList.call()).called(2);
        expect(bloc.state.manases.map((m) => m.manasId), ['b']);
      },
    );

    blocTest<ManasListBloc, ManasListState>(
      'delete failure is swallowed — reload still happens (eventual consistency)',
      build: () {
        when(() => deleteManas.call(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('relay down')),
        );
        when(() => getList.call()).thenAnswer((_) async => const Right([]));
        return ManasListBloc(getList, deleteManas);
      },
      act: (bloc) => bloc.add(const ManasListDeleteEvent('a')),
      wait: const Duration(milliseconds: 30),
      verify: (_) {
        verify(() => deleteManas.call('a')).called(1);
        // Even on delete failure the bloc adds LoadEvent → 1 list call.
        verify(() => getList.call()).called(1);
      },
    );
  });
}
