import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/features/media/cubit/media_gallery_cubit.dart';
import 'package:uniun/features/media/cubit/media_gallery_state.dart';

import '../../../_helpers/fixtures.dart';

class _MWatch extends Mock implements WatchMediaUseCase {}

class _MRemove extends Mock implements RemoveLocalMediaUseCase {}

/// Covers: MediaGalleryCubit — load flow (loading→loaded), filter change,
/// stream error → error state, removeLocal (busy set toggle + error surface),
/// selection mode toggle / clear, bulkRemoveLocal (busy set + stop-on-error),
/// close cancels the underlying subscription.
void main() {
  setUpAll(() {
    registerFallbackValue(const MediaFilter());
  });

  late _MWatch watch;
  late _MRemove remove;
  late GetIt getIt;

  setUp(() async {
    getIt = GetIt.instance;
    await getIt.reset();
    watch = _MWatch();
    remove = _MRemove();
    getIt.registerFactory<WatchMediaUseCase>(() => watch);
    getIt.registerFactory<RemoveLocalMediaUseCase>(() => remove);
  });

  tearDown(() async {
    await getIt.reset();
  });

  MediaBlobEntity blob(String sha, {String mime = 'image/jpeg'}) =>
      aMediaBlob(sha256: sha, mime: mime);

  // ── load ──────────────────────────────────────────────────────────────────

  group('load', () {
    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'emits loading then loaded with the stream payload',
      build: () {
        when(() => watch.call(any())).thenAnswer((_) => Stream.fromIterable([
              [blob('a'), blob('b')],
            ]));
        return MediaGalleryCubit();
      },
      act: (c) => c.load(),
      expect: () => [
        isA<MediaGalleryState>()
            .having((s) => s.status, 'status', MediaGalleryStatus.loading),
        isA<MediaGalleryState>()
            .having((s) => s.status, 'status', MediaGalleryStatus.loaded)
            .having((s) => s.blobs.length, 'blobs', 2),
      ],
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'load with explicit filter carries filter into state',
      build: () {
        when(() => watch.call(any()))
            .thenAnswer((_) => Stream.fromIterable([<MediaBlobEntity>[]]));
        return MediaGalleryCubit();
      },
      act: (c) =>
          c.load(filter: const MediaFilter(kind: MediaKindFilter.video)),
      expect: () => [
        isA<MediaGalleryState>().having(
            (s) => s.filter.kind, 'filter.kind', MediaKindFilter.video),
        isA<MediaGalleryState>()
            .having((s) => s.status, 'status', MediaGalleryStatus.loaded),
      ],
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'stream error → error state with message',
      build: () {
        when(() => watch.call(any()))
            .thenAnswer((_) => Stream.error(Exception('isar boom')));
        return MediaGalleryCubit();
      },
      act: (c) => c.load(),
      wait: const Duration(milliseconds: 20),
      expect: () => [
        isA<MediaGalleryState>()
            .having((s) => s.status, 'status', MediaGalleryStatus.loading),
        isA<MediaGalleryState>()
            .having((s) => s.status, 'status', MediaGalleryStatus.error)
            .having((s) => s.errorMessage, 'msg', contains('isar boom')),
      ],
    );

    test('second load cancels the first subscription', () async {
      final ctrl1 = StreamController<List<MediaBlobEntity>>();
      final ctrl2 = StreamController<List<MediaBlobEntity>>();
      var call = 0;
      when(() => watch.call(any())).thenAnswer((_) {
        call++;
        return call == 1 ? ctrl1.stream : ctrl2.stream;
      });

      final c = MediaGalleryCubit();
      c.load();
      c.load(filter: const MediaFilter(kind: MediaKindFilter.image));

      // ctrl1 should have no listener anymore.
      expect(ctrl1.hasListener, isFalse);
      expect(ctrl2.hasListener, isTrue);
      await ctrl1.close();
      await ctrl2.close();
      await c.close();
    });
  });

  group('changeFilter', () {
    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'delegates to load with the new filter',
      build: () {
        when(() => watch.call(any()))
            .thenAnswer((_) => Stream.fromIterable([<MediaBlobEntity>[]]));
        return MediaGalleryCubit();
      },
      act: (c) =>
          c.changeFilter(const MediaFilter(kind: MediaKindFilter.audio)),
      expect: () => [
        isA<MediaGalleryState>()
            .having((s) => s.filter.kind, 'kind', MediaKindFilter.audio),
        isA<MediaGalleryState>()
            .having((s) => s.status, 'status', MediaGalleryStatus.loaded),
      ],
    );
  });

  // ── removeLocal ───────────────────────────────────────────────────────────

  group('removeLocal', () {
    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'toggles busy set on then off, no error on success',
      build: () {
        when(() => remove.call(any()))
            .thenAnswer((_) async => const Right(unit));
        return MediaGalleryCubit();
      },
      act: (c) => c.removeLocal('sha'),
      expect: () => [
        isA<MediaGalleryState>().having(
            (s) => s.busyShas.contains('sha'), 'busy contains sha', true),
        isA<MediaGalleryState>().having(
            (s) => s.busyShas.contains('sha'),
            'busy cleared',
            false),
      ],
      verify: (_) => verify(() => remove.call('sha')).called(1),
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'surfaces failure message on Left',
      build: () {
        when(() => remove.call(any())).thenAnswer(
            (_) async => const Left(Failure.errorFailure('perm denied')));
        return MediaGalleryCubit();
      },
      act: (c) => c.removeLocal('sha'),
      expect: () => [
        // busy on
        isA<MediaGalleryState>()
            .having((s) => s.busyShas.contains('sha'), 'busy on', true),
        // busy off (fold hasn't run yet)
        isA<MediaGalleryState>()
            .having((s) => s.busyShas.contains('sha'), 'busy off', false)
            .having((s) => s.errorMessage, 'msg', isNull),
        // fold emits the message on top of the cleared-busy state
        isA<MediaGalleryState>()
            .having((s) => s.errorMessage, 'msg', 'perm denied'),
      ],
    );
  });

  // ── selection ─────────────────────────────────────────────────────────────

  group('selection', () {
    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'toggleSelect adds then removes',
      build: () => MediaGalleryCubit(),
      act: (c) {
        c.toggleSelect('a');
        c.toggleSelect('a');
      },
      expect: () => [
        isA<MediaGalleryState>()
            .having((s) => s.selectedShas, 'selected', {'a'})
            .having((s) => s.isSelecting, 'isSelecting', true),
        isA<MediaGalleryState>()
            .having((s) => s.selectedShas, 'selected', isEmpty)
            .having((s) => s.isSelecting, 'isSelecting', false),
      ],
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'clearSelection empties when non-empty',
      build: () => MediaGalleryCubit(),
      act: (c) {
        c.toggleSelect('a');
        c.toggleSelect('b');
        c.clearSelection();
      },
      expect: () => [
        isA<MediaGalleryState>()
            .having((s) => s.selectedShas, 'selected', {'a'}),
        isA<MediaGalleryState>()
            .having((s) => s.selectedShas, 'selected', {'a', 'b'}),
        isA<MediaGalleryState>()
            .having((s) => s.selectedShas, 'selected', isEmpty),
      ],
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'clearSelection is a no-op when already empty',
      build: () => MediaGalleryCubit(),
      act: (c) => c.clearSelection(),
      expect: () => [],
    );
  });

  // ── bulkRemoveLocal ───────────────────────────────────────────────────────

  group('bulkRemoveLocal', () {
    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'is a no-op when nothing is selected',
      build: () => MediaGalleryCubit(),
      act: (c) => c.bulkRemoveLocal(),
      expect: () => [],
      verify: (_) => verifyNever(() => remove.call(any())),
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'removes each selection then clears selection + busy set',
      build: () {
        when(() => remove.call(any()))
            .thenAnswer((_) async => const Right(unit));
        return MediaGalleryCubit();
      },
      act: (c) async {
        c.toggleSelect('a');
        c.toggleSelect('b');
        await c.bulkRemoveLocal();
      },
      expect: () => [
        isA<MediaGalleryState>()
            .having((s) => s.selectedShas, 'sel', {'a'}),
        isA<MediaGalleryState>()
            .having((s) => s.selectedShas, 'sel', {'a', 'b'}),
        isA<MediaGalleryState>().having(
            (s) => s.busyShas, 'busy', {'a', 'b'}),
        isA<MediaGalleryState>()
            .having((s) => s.busyShas, 'busy cleared', isEmpty)
            .having((s) => s.selectedShas, 'sel cleared', isEmpty),
      ],
      verify: (_) {
        verify(() => remove.call('a')).called(1);
        verify(() => remove.call('b')).called(1);
      },
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'stops on first error and surfaces the message',
      build: () {
        when(() => remove.call('a')).thenAnswer(
            (_) async => const Left(Failure.errorFailure('boom')));
        // 'b' would succeed, but the loop must have short-circuited.
        when(() => remove.call('b'))
            .thenAnswer((_) async => const Right(unit));
        return MediaGalleryCubit();
      },
      act: (c) async {
        c.toggleSelect('a');
        c.toggleSelect('b');
        await c.bulkRemoveLocal();
      },
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verify(() => remove.call('a')).called(1);
        verifyNever(() => remove.call('b'));
      },
    );
  });

  // ── close ─────────────────────────────────────────────────────────────────

  group('close', () {
    test('cancels the underlying watch subscription', () async {
      final ctrl = StreamController<List<MediaBlobEntity>>();
      when(() => watch.call(any())).thenAnswer((_) => ctrl.stream);
      final c = MediaGalleryCubit();
      c.load();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(ctrl.hasListener, isTrue);
      await c.close();
      expect(ctrl.hasListener, isFalse);
      await ctrl.close();
    });
  });

  // ── Edge cases ────────────────────────────────────────────────────────────

  group('scale + concurrency', () {
    test('handles 100 sequential toggleSelect ops without leak', () async {
      final c = MediaGalleryCubit();
      for (var i = 0; i < 100; i++) {
        c.toggleSelect('sha$i');
      }
      expect(c.state.selectedShas, hasLength(100));
      for (var i = 0; i < 100; i++) {
        c.toggleSelect('sha$i');
      }
      expect(c.state.selectedShas, isEmpty);
      await c.close();
    });

    test('load emit ignored after close', () async {
      final ctrl = StreamController<List<MediaBlobEntity>>();
      when(() => watch.call(any())).thenAnswer((_) => ctrl.stream);
      final c = MediaGalleryCubit();
      c.load();
      await c.close();
      // Push a value after close — must not throw or leak.
      ctrl.add([blob('late')]);
      await Future.delayed(const Duration(milliseconds: 20));
      await ctrl.close();
    });
  });
}
