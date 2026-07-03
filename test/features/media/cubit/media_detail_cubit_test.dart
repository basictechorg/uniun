import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/repositories/media_repository.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/features/media/cubit/media_detail_cubit.dart';

import '../../../_helpers/fixtures.dart';

class _MRepo extends Mock implements MediaRepository {}

class _MRemove extends Mock implements RemoveLocalMediaUseCase {}

/// Covers: MediaDetailCubit — load (present / absent / failure), removeLocal
/// (success returns true and toggles busy; failure returns false and surfaces
/// the message), and close cleanup.
void main() {
  late _MRepo repo;
  late _MRemove remove;
  late GetIt getIt;

  setUp(() async {
    getIt = GetIt.instance;
    await getIt.reset();
    repo = _MRepo();
    remove = _MRemove();
    getIt.registerFactory<MediaRepository>(() => repo);
    getIt.registerFactory<RemoveLocalMediaUseCase>(() => remove);
  });

  tearDown(() async {
    await getIt.reset();
  });

  // ── load ──────────────────────────────────────────────────────────────────

  group('load', () {
    blocTest<MediaDetailCubit, MediaDetailState>(
      'sets blob when repo returns Right(blob)',
      build: () {
        when(() => repo.getCachedBySha('sha'))
            .thenAnswer((_) async => Right(aMediaBlob(sha256: 'sha')));
        return MediaDetailCubit(sha256: 'sha');
      },
      act: (c) => c.load(),
      expect: () => [
        isA<MediaDetailState>().having(
            (s) => s.blob?.sha256, 'blob.sha256', 'sha'),
      ],
    );

    blocTest<MediaDetailCubit, MediaDetailState>(
      'emits nothing when repo returns Right(null)',
      build: () {
        when(() => repo.getCachedBySha('nope'))
            .thenAnswer((_) async => const Right<Failure, MediaBlobEntity?>(null));
        return MediaDetailCubit(sha256: 'nope');
      },
      act: (c) => c.load(),
      expect: () => [],
    );

    blocTest<MediaDetailCubit, MediaDetailState>(
      'surfaces failure message on Left',
      build: () {
        when(() => repo.getCachedBySha(any())).thenAnswer(
            (_) async => const Left(Failure.errorFailure('read error')));
        return MediaDetailCubit(sha256: 'sha');
      },
      act: (c) => c.load(),
      expect: () => [
        isA<MediaDetailState>()
            .having((s) => s.errorMessage, 'msg', 'read error'),
      ],
    );
  });

  // ── removeLocal ───────────────────────────────────────────────────────────

  group('removeLocal', () {
    test('returns true and toggles busy on success', () async {
      when(() => remove.call('sha'))
          .thenAnswer((_) async => const Right(unit));
      final c = MediaDetailCubit(sha256: 'sha');
      final states = <MediaDetailState>[];
      c.stream.listen(states.add);
      final ok = await c.removeLocal();
      await c.close();
      expect(ok, isTrue);
      // Exactly one busy-true emit; page pops on true so no busy-false is required.
      expect(states.first.busy, isTrue);
    });

    test('returns false, clears busy and surfaces message on failure',
        () async {
      when(() => remove.call('sha')).thenAnswer(
          (_) async => const Left(Failure.errorFailure('perm denied')));
      final c = MediaDetailCubit(sha256: 'sha');
      final ok = await c.removeLocal();
      expect(ok, isFalse);
      expect(c.state.busy, isFalse);
      expect(c.state.errorMessage, 'perm denied');
      await c.close();
    });
  });

  // ── close ─────────────────────────────────────────────────────────────────

  test('close completes without throw', () async {
    when(() => repo.getCachedBySha(any())).thenAnswer((_) async =>
        const Right<Failure, MediaBlobEntity?>(null));
    final c = MediaDetailCubit(sha256: 'sha');
    await c.load();
    await c.close();
    // isClosed is not directly exposed on Cubit but a second close is a no-op —
    // if the first didn't succeed this would throw.
    await c.close();
  });
}
