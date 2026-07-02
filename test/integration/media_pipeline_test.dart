import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/blossom_client.dart';
import 'package:uniun/data/datasources/media_cache_data_source.dart';
import 'package:uniun/data/models/media/media_cache_model.dart';
import 'package:uniun/data/repositories/media_repository_impl.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';
import 'package:uniun/domain/repositories/user_server_list_repository.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/isar_test_harness.dart';

class _MBlossom extends Mock implements BlossomClient {}

class _MServerList extends Mock implements UserServerListRepository {}

class _MKeys extends Mock implements GetActiveUserKeysUseCase {}

/// End-to-end media pipeline: real Isar + real MediaCacheDataSource +
/// real MediaRepositoryImpl + real use cases; only BlossomClient (network),
/// UserServerListRepository (Nostr publish), and GetActiveUserKeysUseCase
/// (secure keystore) are stubbed.
///
/// Verifies: upload → gallery emits → detail loads → delete → gallery
/// re-emits without the row; multi-upload dedup; watch stream reactivity;
/// filter kind branches on real data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kBlossom = 'https://blossom.example';
  const keys = kSigningKeys;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(keys);
  });

  late Isar isar;
  late Directory support;
  late MediaCacheDataSource cache;
  late MediaRepositoryImpl repo;
  late _MBlossom blossom;
  late _MServerList serverList;
  late _MKeys keysUC;
  late UploadMediaUseCase upload;
  late DownloadMediaUseCase download;
  late SaveLocalMediaUseCase saveLocal;
  late RemoveLocalMediaUseCase remove;
  late WatchMediaUseCase watch;

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);
  String shaOf(Uint8List b) => crypto.sha256.convert(b).toString();

  setUp(() async {
    isar = await openTestIsar();
    support = await Directory.systemTemp.createTemp('uniun_media_int_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationSupportDirectory') return support.path;
        return null;
      },
    );

    cache = MediaCacheDataSource();
    blossom = _MBlossom();
    serverList = _MServerList();
    keysUC = _MKeys();

    when(() => keysUC.call()).thenAnswer((_) async => const Right(keys));
    when(() => serverList.getServers())
        .thenAnswer((_) async => const Right([kBlossom]));
    when(() => serverList.setServers(any()))
        .thenAnswer((_) async => const Right(unit));
    when(() => blossom.head(any(), any(), ext: any(named: 'ext')))
        .thenAnswer((_) async => false);
    when(() => blossom.upload(
          serverUrl: any(named: 'serverUrl'),
          bytes: any(named: 'bytes'),
          mime: any(named: 'mime'),
          sha256: any(named: 'sha256'),
          keys: any(named: 'keys'),
        )).thenAnswer((_) async => const BlobDescriptor(
          url: 'x',
          sha256: 'x',
          size: 0,
          mime: 'image/jpeg',
        ));

    repo = MediaRepositoryImpl(
      isar: isar,
      blossom: blossom,
      cache: cache,
      serverList: serverList,
      getActiveUserKeys: keysUC,
    );
    upload = UploadMediaUseCase(repo);
    download = DownloadMediaUseCase(repo);
    saveLocal = SaveLocalMediaUseCase(repo);
    remove = RemoveLocalMediaUseCase(repo);
    watch = WatchMediaUseCase(repo);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await isar.close(deleteFromDisk: true);
    if (await support.exists()) await support.delete(recursive: true);
  });

  // ── upload → gallery → detail → delete ────────────────────────────────────

  test('upload persists cache row + writes disk file + gallery emits it',
      () async {
    final data = bytes('hello');
    final sha = shaOf(data);

    final res = await upload.call(
      UploadMediaInput(bytes: data, mime: 'image/jpeg', filename: 'a.jpg'),
    );
    expect(res.isRight(), isTrue);

    // Isar row exists.
    final row = await isar.mediaCacheModels
        .filter()
        .sha256EqualTo(sha)
        .findFirst();
    expect(row, isNotNull);
    expect(row!.mime, 'image/jpeg');
    expect(row.sizeBytes, 5);

    // File on disk.
    expect(await File(row.localPath).exists(), isTrue);
    expect(await File(row.localPath).readAsBytes(), data);

    // Gallery emits the blob.
    final blobs = await watch.call(null).first;
    expect(blobs.map((b) => b.sha256).toList(), [sha]);
  });

  test('delete removes the row, the file, and the gallery emission',
      () async {
    final data = bytes('hello');
    final sha = shaOf(data);
    await upload.call(
      UploadMediaInput(bytes: data, mime: 'image/jpeg'),
    );

    final rowBefore = await isar.mediaCacheModels
        .filter()
        .sha256EqualTo(sha)
        .findFirst();
    expect(rowBefore, isNotNull);
    expect(await File(rowBefore!.localPath).exists(), isTrue);

    final removed = await remove.call(sha);
    expect(removed, const Right<Failure, Unit>(unit));

    final rowAfter = await isar.mediaCacheModels
        .filter()
        .sha256EqualTo(sha)
        .findFirst();
    expect(rowAfter, isNull);
    expect(await File(rowBefore.localPath).exists(), isFalse);

    final blobs = await watch.call(null).first;
    expect(blobs, isEmpty);
  });

  // ── multi-upload ──────────────────────────────────────────────────────────

  test('multi-upload of three distinct blobs → three rows, three files',
      () async {
    final a = bytes('one');
    final b = bytes('two');
    final c = bytes('three');

    await upload.call(UploadMediaInput(bytes: a, mime: 'image/jpeg'));
    await upload.call(UploadMediaInput(bytes: b, mime: 'image/png'));
    await upload.call(UploadMediaInput(bytes: c, mime: 'application/pdf'));

    final rows = await isar.mediaCacheModels.where().findAll();
    expect(rows, hasLength(3));

    final onDisk = <bool>[];
    for (final r in rows) {
      onDisk.add(await File(r.localPath).exists());
    }
    expect(onDisk, everyElement(isTrue));
  });

  test('multi-upload of the same bytes → single row (dedup by SHA)',
      () async {
    // Server dedup: HEAD returns true on the second call because the first
    // upload wrote the metadata.
    var headCalls = 0;
    when(() => blossom.head(any(), any(), ext: any(named: 'ext')))
        .thenAnswer((_) async {
      headCalls++;
      return headCalls > 1;
    });

    final data = bytes('same');
    final r1 = await upload.call(UploadMediaInput(bytes: data, mime: 'image/jpeg'));
    final r2 = await upload.call(UploadMediaInput(bytes: data, mime: 'image/jpeg'));

    expect(r1.isRight(), isTrue);
    expect(r2.isRight(), isTrue);

    // Second upload should have skipped the network call.
    verify(() => blossom.upload(
          serverUrl: any(named: 'serverUrl'),
          bytes: any(named: 'bytes'),
          mime: any(named: 'mime'),
          sha256: any(named: 'sha256'),
          keys: any(named: 'keys'),
        )).called(1);

    // Only one Isar row.
    final rows = await isar.mediaCacheModels.where().findAll();
    expect(rows, hasLength(1));
  });

  // ── watch stream reactivity ───────────────────────────────────────────────

  test('watch stream re-emits after upload and after delete', () async {
    final emissions = <List<String>>[];
    final sub = watch.call(null).listen((blobs) {
      emissions.add(blobs.map((b) => b.sha256).toList());
    });
    // First emission (fireImmediately): empty.
    await Future.delayed(const Duration(milliseconds: 20));

    final data = bytes('watch');
    final sha = shaOf(data);
    await upload.call(UploadMediaInput(bytes: data, mime: 'image/jpeg'));
    await Future.delayed(const Duration(milliseconds: 40));

    await remove.call(sha);
    await Future.delayed(const Duration(milliseconds: 40));

    await sub.cancel();
    expect(emissions.first, isEmpty);
    expect(emissions.any((e) => e.contains(sha)), isTrue);
    expect(emissions.last, isEmpty);
  });

  // ── filter kind branches ──────────────────────────────────────────────────

  test('MediaFilter.kind partitions the emitted rows correctly', () async {
    await upload.call(UploadMediaInput(
      bytes: bytes('img'),
      mime: 'image/jpeg',
    ));
    await upload.call(UploadMediaInput(
      bytes: bytes('vid'),
      mime: 'video/mp4',
    ));
    await upload.call(UploadMediaInput(
      bytes: bytes('doc'),
      mime: 'application/pdf',
    ));
    await upload.call(UploadMediaInput(
      bytes: bytes('aud'),
      mime: 'audio/mpeg',
    ));

    final image = await watch.call(
      const MediaFilter(kind: MediaKindFilter.image),
    ).first;
    expect(image, hasLength(1));
    expect(image.single.mime, 'image/jpeg');

    final video = await watch.call(
      const MediaFilter(kind: MediaKindFilter.video),
    ).first;
    expect(video, hasLength(1));

    final audio = await watch.call(
      const MediaFilter(kind: MediaKindFilter.audio),
    ).first;
    expect(audio, hasLength(1));

    final files = await watch.call(
      const MediaFilter(kind: MediaKindFilter.file),
    ).first;
    expect(files, hasLength(1));
    expect(files.single.mime, 'application/pdf');

    final all = await watch.call(const MediaFilter()).first;
    expect(all, hasLength(4));
  });

  // ── saveLocal (draft path) → upload (publish) sequence ────────────────────

  test('saveLocal then upload of the same bytes reuses the cache file',
      () async {
    final data = bytes('draft');
    final sha = shaOf(data);

    // Draft path: no network call.
    await saveLocal.call(SaveLocalMediaInput(
      bytes: data,
      mime: 'image/jpeg',
      filename: 'draft.jpg',
    ));
    verifyNever(() => blossom.upload(
          serverUrl: any(named: 'serverUrl'),
          bytes: any(named: 'bytes'),
          mime: any(named: 'mime'),
          sha256: any(named: 'sha256'),
          keys: any(named: 'keys'),
        ));

    final rowA = await isar.mediaCacheModels
        .filter()
        .sha256EqualTo(sha)
        .findFirst();
    expect(rowA, isNotNull);

    // Now "publish": HEAD returns true (server already has it — unlikely but
    // valid), so uploadBytes must NOT call upload.
    when(() => blossom.head(any(), any(), ext: any(named: 'ext')))
        .thenAnswer((_) async => true);

    await upload.call(UploadMediaInput(bytes: data, mime: 'image/jpeg'));
    verifyNever(() => blossom.upload(
          serverUrl: any(named: 'serverUrl'),
          bytes: any(named: 'bytes'),
          mime: any(named: 'mime'),
          sha256: any(named: 'sha256'),
          keys: any(named: 'keys'),
        ));

    // Still one row for this sha.
    final rows =
        await isar.mediaCacheModels.filter().sha256EqualTo(sha).findAll();
    expect(rows, hasLength(1));
  });

  // ── downloadBySha over cache-hit vs. network path ─────────────────────────

  test('downloadBySha: cache-hit reuses the file, cache-miss fetches',
      () async {
    // Prime the cache by uploading.
    final data = bytes('one');
    final sha = shaOf(data);
    await upload.call(UploadMediaInput(bytes: data, mime: 'image/jpeg'));
    clearInteractions(blossom);

    // Cache-hit: no downloadFromUrl call.
    await download.call(DownloadMediaInput(
      sha256: sha,
      url: '$kBlossom/$sha.jpg',
      mime: 'image/jpeg',
    ));
    verifyNever(() => blossom.downloadFromUrl(any()));

    // Cache-miss for a different sha: goes to network.
    when(() => blossom.downloadFromUrl(any()))
        .thenAnswer((_) async => bytes('remote'));
    final res = await download.call(const DownloadMediaInput(
      sha256: 'missing_sha',
      url: '$kBlossom/missing_sha.jpg',
      mime: 'image/jpeg',
    ));
    expect(res.isRight(), isTrue);
    verify(() => blossom.downloadFromUrl(any())).called(1);
  });

  // ── failure paths bubble to the use-case boundary ─────────────────────────

  test('upload failure surfaces as Left(Failure) at the use case', () async {
    when(() => blossom.upload(
          serverUrl: any(named: 'serverUrl'),
          bytes: any(named: 'bytes'),
          mime: any(named: 'mime'),
          sha256: any(named: 'sha256'),
          keys: any(named: 'keys'),
        )).thenThrow(BlossomException(413, 'too large'));

    final res = await upload.call(
      UploadMediaInput(bytes: bytes('big'), mime: 'image/jpeg'),
    );
    expect(res.isLeft(), isTrue);
  });

  test('remove of a missing sha is Right(unit) (idempotent)', () async {
    final res = await remove.call('nope');
    expect(res, const Right<Failure, Unit>(unit));
  });
}
