import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/repositories/ai_model_repository.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';

class _MockAIModelRepository extends Mock implements AIModelRepository {}

const _aModel = AIModelEntity(
  modelId: AIModelId.deepseekR1,
  sizeLabel: '1.7 GB',
  sizeBytes: 1000,
  tier: AIModelTier.balanced,
  isRecommended: false,
  optimization: AIModelOptimization.cpu,
  downloadUrl: 'https://example.com/model.task',
);

void main() {
  late _MockAIModelRepository repo;

  setUpAll(() {
    registerFallbackValue(AIModelId.deepseekR1);
  });

  setUp(() {
    repo = _MockAIModelRepository();
  });

  test('GetAvailableAIModelsUseCase delegates to getAvailableModels', () async {
    when(() => repo.getAvailableModels()).thenAnswer((_) async => [_aModel]);

    final result = await GetAvailableAIModelsUseCase(repo).call();

    expect(result, [_aModel]);
  });

  test('GetActiveAIModelUseCase delegates to getActiveModel', () async {
    when(() => repo.getActiveModel()).thenAnswer((_) async => const Right(_aModel));

    final result = await GetActiveAIModelUseCase(repo).call();

    expect(result, const Right<Failure, AIModelEntity?>(_aModel));
  });

  test('DownloadAndActivateAIModelUseCase forwards modelId + cancellation',
      () {
    when(() => repo.downloadAndActivateModel(AIModelId.deepseekR1,
            cancellation: any(named: 'cancellation')))
        .thenAnswer((_) => const Stream.empty());

    final stream = DownloadAndActivateAIModelUseCase(repo).call(AIModelId.deepseekR1);

    expect(stream, isA<Stream<AIModelDownloadEvent>>());
    verify(() => repo.downloadAndActivateModel(AIModelId.deepseekR1,
            cancellation: any(named: 'cancellation')))
        .called(1);
  });

  test('ClearActiveAIModelUseCase delegates to clearActiveModel', () async {
    when(() => repo.clearActiveModel()).thenAnswer((_) async => const Right(unit));

    final result = await ClearActiveAIModelUseCase(repo).call();

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('GetDownloadedModelIdsUseCase delegates to getDownloadedModelIds',
      () async {
    when(() => repo.getDownloadedModelIds()).thenAnswer((_) async => {AIModelId.deepseekR1});

    final result = await GetDownloadedModelIdsUseCase(repo).call();

    expect(result, {AIModelId.deepseekR1});
  });

  test('DeleteAIModelUseCase delegates to deleteModel', () async {
    when(() => repo.deleteModel(AIModelId.deepseekR1)).thenAnswer((_) async => const Right(unit));

    final result = await DeleteAIModelUseCase(repo).call(AIModelId.deepseekR1);

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('GetOrphanedModelFilesSizeBytesUseCase delegates', () async {
    when(() => repo.getOrphanedModelFilesSizeBytes()).thenAnswer((_) async => 1024);

    final result = await GetOrphanedModelFilesSizeBytesUseCase(repo).call();

    expect(result, 1024);
  });

  test('CleanupOrphanedModelFilesUseCase delegates', () async {
    when(() => repo.cleanupOrphanedModelFiles()).thenAnswer((_) async => const Right(2));

    final result = await CleanupOrphanedModelFilesUseCase(repo).call();

    expect(result, const Right<Failure, int>(2));
  });
}
