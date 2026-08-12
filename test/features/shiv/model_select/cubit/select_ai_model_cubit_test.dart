import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/features/shiv/model_select/cubit/select_ai_model_cubit.dart';
import 'package:uniun/features/shiv/rag/embedding/embedding_model_downloader.dart';

class _MockGetAvailable extends Mock implements GetAvailableAIModelsUseCase {}

class _MockGetActive extends Mock implements GetActiveAIModelUseCase {}

class _MockGetDownloaded extends Mock implements GetDownloadedModelIdsUseCase {}

class _MockDownload extends Mock implements DownloadAndActivateAIModelUseCase {}

class _MockDeleteModel extends Mock implements DeleteAIModelUseCase {}

class _MockEmbeddingDownloader extends Mock implements EmbeddingModelDownloader {}

class _MockConnectCloud extends Mock implements ConnectUniunCloudUseCase {}

class _MockIsCloudConnected extends Mock implements IsUniunCloudConnectedUseCase {}

class _MockListCloudModels extends Mock implements ListCloudLlmModelsUseCase {}

class _MockSetBackend extends Mock implements SetActiveLlmBackendUseCase {}

class _MockSetLlmModel extends Mock implements SetActiveLlmModelUseCase {}

class _MockGetLlmModel extends Mock implements GetActiveLlmModelUseCase {}

class _MockGetBackend extends Mock implements GetActiveLlmBackendUseCase {}

class _MockGetOrphanedSize extends Mock
    implements GetOrphanedModelFilesSizeBytesUseCase {}

class _MockCleanupOrphaned extends Mock implements CleanupOrphanedModelFilesUseCase {}

AIModelEntity _entry(AIModelId id, {bool isRecommended = false}) => AIModelEntity(
      modelId: id,
      sizeLabel: '1 GB',
      sizeBytes: 1000,
      tier: AIModelTier.balanced,
      isRecommended: isRecommended,
      optimization: AIModelOptimization.cpu,
      downloadUrl: 'https://example.com/$id',
    );

/// Directly emits [state], bypassing whatever the cubit itself would
/// compute — the same trick `blocTest`'s own `seed` uses internally. Needed
/// here because plain `test()` (not `blocTest`) drives every case below, to
/// sidestep the cubit's unawaited constructor `_init()` racing `blocTest`'s
/// synchronous `build` contract (see `ready()`'s doc for the full story).
void _seed(SelectAIModelCubit cubit, SelectAIModelState state) {
  // ignore: invalid_use_of_protected_member
  cubit.emit(state);
}

void main() {
  late _MockGetAvailable getAvailable;
  late _MockGetActive getActive;
  late _MockGetDownloaded getDownloaded;
  late _MockDownload download;
  late _MockDeleteModel deleteModel;
  late _MockEmbeddingDownloader embeddingDownloader;
  late _MockConnectCloud connectCloud;
  late _MockIsCloudConnected isCloudConnected;
  late _MockListCloudModels listCloudModels;
  late _MockSetBackend setBackend;
  late _MockSetLlmModel setLlmModel;
  late _MockGetLlmModel getLlmModel;
  late _MockGetBackend getBackend;
  late _MockGetOrphanedSize getOrphanedSize;
  late _MockCleanupOrphaned cleanupOrphaned;

  setUpAll(() {
    registerFallbackValue(AIModelId.qwen25_05b);
    registerFallbackValue(LlmBackendType.localGemma);
  });

  /// Stubs a "clean slate" `_init()` — no active model, nothing downloaded,
  /// local backend, cloud not connected. Individual tests override what
  /// they need before constructing the cubit.
  void stubDefaults() {
    when(() => getAvailable.call()).thenAnswer((_) async => [
          _entry(AIModelId.qwen25_05b, isRecommended: true),
          _entry(AIModelId.deepseekR1),
        ]);
    when(() => getActive.call()).thenAnswer((_) async => const Right(null));
    when(() => getDownloaded.call()).thenAnswer((_) async => <AIModelId>{});
    when(() => getBackend.call())
        .thenAnswer((_) async => const Right(LlmBackendType.localGemma));
    when(() => isCloudConnected.call()).thenAnswer((_) async => false);
    when(() => getOrphanedSize.call()).thenAnswer((_) async => 0);
    when(() => embeddingDownloader.isDownloaded()).thenAnswer((_) async => true);
  }

  SelectAIModelCubit build() => SelectAIModelCubit(
        getAvailable,
        getActive,
        getDownloaded,
        download,
        deleteModel,
        embeddingDownloader,
        connectCloud,
        isCloudConnected,
        listCloudModels,
        setBackend,
        setLlmModel,
        getLlmModel,
        getBackend,
        getOrphanedSize,
        cleanupOrphaned,
      );

  /// Constructs the cubit and flushes its unawaited constructor `_init()`
  /// to completion before handing it back, so every test starts from a
  /// known, settled state instead of racing `_init()`'s pending emissions.
  /// Two microtask flushes: one for `_init()` itself, one more for the
  /// `_ensureEmbeddingDownloaded()` chain it fires (unawaited) when a model
  /// is already active.
  Future<SelectAIModelCubit> ready() async {
    final cubit = build();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  setUp(() {
    getAvailable = _MockGetAvailable();
    getActive = _MockGetActive();
    getDownloaded = _MockGetDownloaded();
    download = _MockDownload();
    deleteModel = _MockDeleteModel();
    embeddingDownloader = _MockEmbeddingDownloader();
    connectCloud = _MockConnectCloud();
    isCloudConnected = _MockIsCloudConnected();
    listCloudModels = _MockListCloudModels();
    setBackend = _MockSetBackend();
    setLlmModel = _MockSetLlmModel();
    getLlmModel = _MockGetLlmModel();
    getBackend = _MockGetBackend();
    getOrphanedSize = _MockGetOrphanedSize();
    cleanupOrphaned = _MockCleanupOrphaned();
    stubDefaults();
  });

  group('_init (constructor)', () {
    test('picks the recommended model as selected when nothing is active',
        () async {
      final cubit = await ready();

      expect(cubit.state.selectedModelId, AIModelId.qwen25_05b);
      expect(cubit.state.activeModelId, isNull);
      await cubit.close();
    });

    test('an already-active model becomes selectedModelId and triggers an '
        'embedding-presence check', () async {
      when(() => getActive.call())
          .thenAnswer((_) async => Right(_entry(AIModelId.deepseekR1)));
      when(() => embeddingDownloader.isDownloaded()).thenAnswer((_) async => false);
      when(() => embeddingDownloader.downloadIfNeeded()).thenAnswer((_) async {});

      final cubit = await ready();

      expect(cubit.state.selectedModelId, AIModelId.deepseekR1);
      expect(cubit.state.activeModelId, AIModelId.deepseekR1);
      verify(() => embeddingDownloader.downloadIfNeeded()).called(1);
      await cubit.close();
    });

    test('no active model and no recommended entry falls back to the '
        'first catalog entry', () async {
      when(() => getAvailable.call()).thenAnswer((_) async => [
            _entry(AIModelId.deepseekR1),
            _entry(AIModelId.gemma4E2b),
          ]);

      final cubit = await ready();

      expect(cubit.state.selectedModelId, AIModelId.deepseekR1);
      await cubit.close();
    });

    test('when UNIUN Cloud is connected, loads cloud models and the active '
        'cloud model id (only when the active backend IS cloud)', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => listCloudModels.call()).thenAnswer((_) async => const Right([
            LlmModelInfo(
                id: 'claude', displayName: 'Claude', backend: LlmBackendType.uniunCloud),
          ]));
      when(() => getLlmModel.call()).thenAnswer((_) async => const Right(
          LlmModelInfo(
              id: 'claude', displayName: 'Claude', backend: LlmBackendType.uniunCloud)));

      final cubit = await ready();

      expect(cubit.state.cloudModels, hasLength(1));
      expect(cubit.state.activeCloudModelId, 'claude');
      await cubit.close();
    });

    test('a cloud-connected account whose active model is actually local '
        'reports no activeCloudModelId', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => listCloudModels.call()).thenAnswer((_) async => const Right([
            LlmModelInfo(
                id: 'claude', displayName: 'Claude', backend: LlmBackendType.uniunCloud),
          ]));
      when(() => getLlmModel.call()).thenAnswer((_) async => Right(
          LlmModelInfo(
              id: AIModelId.qwen25_05b.name,
              displayName: 'Qwen',
              backend: LlmBackendType.localGemma)));

      final cubit = await ready();

      expect(cubit.state.activeCloudModelId, isNull);
      await cubit.close();
    });

    test('cloud list/active-model failures degrade to empty/null, not a '
        'crash', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => listCloudModels.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('x')));
      when(() => getLlmModel.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('x')));

      final cubit = await ready();

      expect(cubit.state.cloudModels, isEmpty);
      expect(cubit.state.activeCloudModelId, isNull);
      await cubit.close();
    });

    test('a getBackend failure degrades to localGemma', () async {
      when(() => getBackend.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('x')));

      final cubit = await ready();

      expect(cubit.state.activeBackend, LlmBackendType.localGemma);
      await cubit.close();
    });
  });

  group('selectModel', () {
    test('updates selectedModelId', () async {
      final cubit = await ready();

      cubit.selectModel(AIModelId.gemma4E2b);

      expect(cubit.state.selectedModelId, AIModelId.gemma4E2b);
      await cubit.close();
    });

    test('is a no-op while a download is in progress', () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(status: SelectAIModelStatus.downloading));

      cubit.selectModel(AIModelId.gemma4E2b);

      expect(cubit.state.selectedModelId, isNull);
      await cubit.close();
    });
  });

  group('downloadAndActivate', () {
    test('no selected model — no-op', () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState());

      await cubit.downloadAndActivate();

      expect(cubit.state.status, SelectAIModelStatus.initial);
      await cubit.close();
    });

    test('already active — just re-asserts the local backend without '
        'downloading', () async {
      when(() => setBackend.call(any())).thenAnswer((_) async => const Right(unit));
      final cubit = await ready();
      _seed(
          cubit,
          const SelectAIModelState(
            selectedModelId: AIModelId.qwen25_05b,
            activeModelId: AIModelId.qwen25_05b,
            activeBackend: LlmBackendType.uniunCloud,
          ));

      await cubit.downloadAndActivate();

      expect(cubit.state.status, SelectAIModelStatus.done);
      expect(cubit.state.activeBackend, LlmBackendType.localGemma);
      verifyNever(() => download.call(any(), cancellation: any(named: 'cancellation')));
      await cubit.close();
    });

    test('is a no-op while already downloading', () async {
      final cubit = await ready();
      _seed(
          cubit,
          const SelectAIModelState(
              selectedModelId: AIModelId.deepseekR1,
              status: SelectAIModelStatus.downloading));

      await cubit.downloadAndActivate();

      verifyNever(() => download.call(any(), cancellation: any(named: 'cancellation')));
      await cubit.close();
    });

    test('streams progress, downloads the embedder once, sets the local '
        'backend, then completes', () async {
      when(() => download.call(any(), cancellation: any(named: 'cancellation')))
          .thenAnswer((_) => Stream.fromIterable([
                const AIModelDownloadEvent.progress(0.5),
                const AIModelDownloadEvent.complete(AIModelId.deepseekR1),
              ]));
      when(() => embeddingDownloader.isDownloaded()).thenAnswer((_) async => false);
      when(() => embeddingDownloader.downloadIfNeeded()).thenAnswer((_) async {});
      when(() => setBackend.call(any())).thenAnswer((_) async => const Right(unit));
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(selectedModelId: AIModelId.deepseekR1));
      final states = <SelectAIModelState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.downloadAndActivate();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(states.map((s) => s.status), contains(SelectAIModelStatus.downloading));
      expect(states.any((s) => s.downloadProgress == 0.5), isTrue);
      expect(states.any((s) => s.isEmbeddingDownloading), isTrue);
      expect(cubit.state.status, SelectAIModelStatus.done);
      expect(cubit.state.activeModelId, AIModelId.deepseekR1);
      expect(cubit.state.isEmbeddingDownloading, isFalse);
      await cubit.close();
    });

    test('skips the embedder download when it is already present', () async {
      when(() => download.call(any(), cancellation: any(named: 'cancellation')))
          .thenAnswer((_) =>
              Stream.fromIterable([const AIModelDownloadEvent.complete(AIModelId.deepseekR1)]));
      when(() => embeddingDownloader.isDownloaded()).thenAnswer((_) async => true);
      when(() => setBackend.call(any())).thenAnswer((_) async => const Right(unit));
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(selectedModelId: AIModelId.deepseekR1));

      await cubit.downloadAndActivate();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verifyNever(() => embeddingDownloader.downloadIfNeeded());
      await cubit.close();
    });

    test('a failed event emits an error status with the message', () async {
      when(() => download.call(any(), cancellation: any(named: 'cancellation')))
          .thenAnswer(
              (_) => Stream.fromIterable([const AIModelDownloadEvent.failed('boom')]));
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(selectedModelId: AIModelId.deepseekR1));

      await cubit.downloadAndActivate();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.status, SelectAIModelStatus.error);
      expect(cubit.state.errorMessage, 'boom');
      await cubit.close();
    });

    test('a stream error emits an error status', () async {
      when(() => download.call(any(), cancellation: any(named: 'cancellation')))
          .thenAnswer((_) => Stream.error(Exception('network down')));
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(selectedModelId: AIModelId.deepseekR1));

      await cubit.downloadAndActivate();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.status, SelectAIModelStatus.error);
      await cubit.close();
    });
  });

  group('cancelDownload', () {
    test('no-op when not currently downloading', () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState());

      await cubit.cancelDownload();

      expect(cubit.state.status, SelectAIModelStatus.initial);
      await cubit.close();
    });

    test('resets to initial and clears progress/error while downloading',
        () async {
      final cubit = await ready();
      _seed(
          cubit,
          const SelectAIModelState(
            status: SelectAIModelStatus.downloading,
            downloadProgress: 0.4,
            errorMessage: 'stale',
          ));

      await cubit.cancelDownload();

      expect(cubit.state.status, SelectAIModelStatus.initial);
      expect(cubit.state.downloadProgress, 0.0);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });
  });

  group('connectCloud', () {
    test('is a no-op while already connecting', () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(isCloudConnecting: true));

      await cubit.connectCloud();

      verifyNever(() => connectCloud.call());
      await cubit.close();
    });

    test('a connect failure surfaces the failure message', () async {
      when(() => connectCloud.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('bad creds')));
      final cubit = await ready();

      await cubit.connectCloud();

      expect(cubit.state.isCloudConnecting, isFalse);
      expect(cubit.state.cloudErrorMessage, 'bad creds');
      await cubit.close();
    });

    test('a connect success with an empty plan catalog surfaces the '
        'fallback message', () async {
      when(() => connectCloud.call()).thenAnswer((_) async => const Right(unit));
      when(() => listCloudModels.call())
          .thenAnswer((_) async => const Right(<LlmModelInfo>[]));
      final cubit = await ready();

      await cubit.connectCloud();

      expect(cubit.state.cloudErrorMessage, 'No cloud models on this plan');
      await cubit.close();
    });

    test('a connect success with a listCloudModels failure surfaces that '
        'failure\'s message instead of the generic fallback', () async {
      when(() => connectCloud.call()).thenAnswer((_) async => const Right(unit));
      when(() => listCloudModels.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('rate limited')));
      final cubit = await ready();

      await cubit.connectCloud();

      expect(cubit.state.cloudErrorMessage, 'rate limited');
      await cubit.close();
    });

    test('success with models populates cloudModels and clears connecting',
        () async {
      when(() => connectCloud.call()).thenAnswer((_) async => const Right(unit));
      when(() => listCloudModels.call()).thenAnswer((_) async => const Right([
            LlmModelInfo(id: 'm1', displayName: 'M1', backend: LlmBackendType.uniunCloud),
          ]));
      final cubit = await ready();

      await cubit.connectCloud();

      expect(cubit.state.isCloudConnecting, isFalse);
      expect(cubit.state.cloudModels, hasLength(1));
      await cubit.close();
    });
  });

  group('activateCloudModel', () {
    test('is a no-op while another cloud model is already activating',
        () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(activatingCloudModelId: 'other'));

      await cubit.activateCloudModel('m1');

      verifyNever(() => setBackend.call(any()));
      await cubit.close();
    });

    test('is a no-op while a local download is in progress', () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(status: SelectAIModelStatus.downloading));

      await cubit.activateCloudModel('m1');

      verifyNever(() => setBackend.call(any()));
      await cubit.close();
    });

    test('a setBackend failure surfaces the failure without touching '
        'setActiveModel', () async {
      when(() => setBackend.call(any()))
          .thenAnswer((_) async => const Left(Failure.errorFailure('backend down')));
      final cubit = await ready();

      await cubit.activateCloudModel('m1');

      expect(cubit.state.cloudErrorMessage, contains('backend down'));
      verifyNever(() => setLlmModel.call(any()));
      await cubit.close();
    });

    test('a setActiveModel failure (after backend switch succeeds) '
        'surfaces that failure', () async {
      when(() => setBackend.call(any())).thenAnswer((_) async => const Right(unit));
      when(() => setLlmModel.call(any()))
          .thenAnswer((_) async => const Left(Failure.errorFailure('unknown model')));
      final cubit = await ready();

      await cubit.activateCloudModel('m1');

      expect(cubit.state.cloudErrorMessage, contains('unknown model'));
      await cubit.close();
    });

    test('success ensures the embedder, then marks the cloud model active',
        () async {
      when(() => setBackend.call(any())).thenAnswer((_) async => const Right(unit));
      when(() => setLlmModel.call(any())).thenAnswer((_) async => const Right(unit));
      final cubit = await ready();

      await cubit.activateCloudModel('m1');

      expect(cubit.state.activatingCloudModelId, isNull);
      expect(cubit.state.activeCloudModelId, 'm1');
      expect(cubit.state.activeBackend, LlmBackendType.uniunCloud);
      expect(cubit.state.status, SelectAIModelStatus.done);
      await cubit.close();
    });
  });

  group('deleteModel', () {
    test('is a no-op while another delete is in progress', () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(deletingModelId: AIModelId.gemma4E2b));

      await cubit.deleteModel(AIModelId.deepseekR1);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => deleteModel.call(any()));
      await cubit.close();
    });

    test('a failure surfaces the error and clears deletingModelId', () async {
      when(() => deleteModel.call(any()))
          .thenAnswer((_) async => const Left(Failure.errorFailure('busy')));
      final cubit = await ready();

      await cubit.deleteModel(AIModelId.deepseekR1);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.deletingModelId, isNull);
      expect(cubit.state.errorMessage, contains('busy'));
      await cubit.close();
    });

    test('success refreshes downloadedModelIds and clears activeModelId '
        'when the deleted model WAS active', () async {
      when(() => deleteModel.call(any())).thenAnswer((_) async => const Right(unit));
      when(() => getDownloaded.call()).thenAnswer((_) async => <AIModelId>{});
      final cubit = await ready();
      _seed(
          cubit,
          SelectAIModelState(
              activeModelId: AIModelId.deepseekR1,
              selectedModelId: AIModelId.deepseekR1,
              models: [_entry(AIModelId.qwen25_05b)]));

      await cubit.deleteModel(AIModelId.deepseekR1);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.activeModelId, isNull);
      expect(cubit.state.selectedModelId, AIModelId.qwen25_05b);
      await cubit.close();
    });

    test('deleting a non-active, non-selected model leaves those fields '
        'untouched', () async {
      when(() => deleteModel.call(any())).thenAnswer((_) async => const Right(unit));
      when(() => getDownloaded.call()).thenAnswer((_) async => {AIModelId.qwen25_05b});
      final cubit = await ready();
      _seed(
          cubit,
          const SelectAIModelState(
              activeModelId: AIModelId.qwen25_05b,
              selectedModelId: AIModelId.qwen25_05b));

      await cubit.deleteModel(AIModelId.deepseekR1);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.activeModelId, AIModelId.qwen25_05b);
      expect(cubit.state.selectedModelId, AIModelId.qwen25_05b);
      await cubit.close();
    });
  });

  group('cleanupOrphanedFiles', () {
    test('is a no-op (returns null) while already cleaning up', () async {
      final cubit = await ready();
      _seed(cubit, const SelectAIModelState(isCleaningUpFiles: true));

      final result = await cubit.cleanupOrphanedFiles();

      expect(result, isNull);
      verifyNever(() => cleanupOrphaned.call());
      await cubit.close();
    });

    test('a failure clears the flag and returns null', () async {
      when(() => cleanupOrphaned.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('x')));
      final cubit = await ready();

      final result = await cubit.cleanupOrphanedFiles();

      expect(result, isNull);
      expect(cubit.state.isCleaningUpFiles, isFalse);
      await cubit.close();
    });

    test('success clears the flag, zeroes orphanedFilesSizeBytes, and '
        'returns the removed count', () async {
      when(() => cleanupOrphaned.call()).thenAnswer((_) async => const Right(7));
      final cubit = await ready();

      final result = await cubit.cleanupOrphanedFiles();

      expect(result, 7);
      expect(cubit.state.isCleaningUpFiles, isFalse);
      expect(cubit.state.orphanedFilesSizeBytes, 0);
      await cubit.close();
    });
  });

  group('refresh', () {
    test('re-runs the same load as the constructor', () async {
      final cubit = await ready();
      when(() => getAvailable.call()).thenAnswer((_) async => [
            _entry(AIModelId.gemma4E4b, isRecommended: true),
          ]);

      await cubit.refresh();

      expect(cubit.state.models.single.modelId, AIModelId.gemma4E4b);
      await cubit.close();
    });
  });

  group('close', () {
    test('cancels any in-flight download subscription and cancellation '
        'token without throwing', () async {
      when(() => download.call(any(), cancellation: any(named: 'cancellation')))
          .thenAnswer((_) => const Stream.empty());
      final cubit = await ready();
      unawaited(cubit.downloadAndActivate());

      await cubit.close();
    });
  });
}
