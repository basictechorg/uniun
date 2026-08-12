import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart' hide CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/data/datasources/llm/flutter_gemma_gateway.dart';
import 'package:uniun/features/shiv/rag/embedding/embedding_service.dart';

class _MockGateway extends Mock implements FlutterGemmaGateway {}

class _MockEmbeddingModel extends Mock implements EmbeddingModel {}

/// Covers EmbeddingService's real orchestration logic — install-once,
/// GPU→CPU backend fallback, embed()'s lazy-init + degrade-to-empty
/// contract, L2 normalisation — via the FlutterGemmaGateway seam
/// (see docs/AUDIT.md, Group A native-ceiling closure). Before the seam,
/// this class called `FlutterGemma.*` statics directly with no mockable
/// path at all.
void main() {
  setUpAll(() {
    registerFallbackValue(TaskType.retrievalQuery);
    registerFallbackValue(PreferredBackend.cpu);
  });

  late _MockGateway gateway;
  late EmbeddingService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS; // gpu-preferred
    gateway = _MockGateway();
    service = EmbeddingService(gateway);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('ensureInstalled', () {
    test('already active — skips the install call', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);

      await service.ensureInstalled();

      verifyNever(() => gateway.installEmbedder(
            modelAsset: any(named: 'modelAsset'),
            tokenizerAsset: any(named: 'tokenizerAsset'),
          ));
    });

    test('not active — installs with the bundled asset paths', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(false);
      when(() => gateway.installEmbedder(
            modelAsset: any(named: 'modelAsset'),
            tokenizerAsset: any(named: 'tokenizerAsset'),
          )).thenAnswer((_) async {});

      await service.ensureInstalled();

      verify(() => gateway.installEmbedder(
            modelAsset: EmbeddingService.modelAsset,
            tokenizerAsset: EmbeddingService.tokenizerAsset,
          )).called(1);
    });
  });

  group('init', () {
    test('installs (if needed) then opens the embedder on the preferred '
        'backend', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(false);
      when(() => gateway.installEmbedder(
            modelAsset: any(named: 'modelAsset'),
            tokenizerAsset: any(named: 'tokenizerAsset'),
          )).thenAnswer((_) async {});
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);

      await service.init();

      expect(service.isReady, isTrue);
      verify(() => gateway.getActiveEmbedder(preferredBackend: PreferredBackend.gpu))
          .called(1);
    });

    test('is idempotent — a second call is a no-op once ready', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);

      await service.init();
      await service.init();

      verify(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .called(1);
    });

    test('GPU open failure falls back to CPU and still becomes ready',
        () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final cpuModel = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: PreferredBackend.gpu))
          .thenThrow(Exception('Metal texture binding overflow'));
      when(() => gateway.getActiveEmbedder(preferredBackend: PreferredBackend.cpu))
          .thenAnswer((_) async => cpuModel);

      await service.init();

      expect(service.isReady, isTrue);
    });

    test('a failure on both backends degrades to not-ready, not a throw',
        () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenThrow(Exception('native init failed'));

      await service.init();

      expect(service.isReady, isFalse);
    });

    test('an ensureInstalled failure degrades to not-ready, not a throw',
        () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(false);
      when(() => gateway.installEmbedder(
            modelAsset: any(named: 'modelAsset'),
            tokenizerAsset: any(named: 'tokenizerAsset'),
          )).thenThrow(Exception('asset copy failed'));

      await service.init();

      expect(service.isReady, isFalse);
    });
  });

  group('embed', () {
    test('lazily calls init() when not yet ready', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);
      when(() => model.generateEmbedding(any(), taskType: any(named: 'taskType')))
          .thenAnswer((_) async => [0.6, 0.8]); // already unit-norm

      final vec = await service.embed('hello');

      expect(vec, [0.6, 0.8]);
      expect(service.isReady, isTrue);
    });

    test('still not ready after init (model unavailable) — returns []',
        () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenThrow(Exception('no model'));

      final vec = await service.embed('hello');

      expect(vec, isEmpty);
    });

    test('passes retrievalDocument taskType when isDocument:true, '
        'retrievalQuery otherwise', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);
      when(() => model.generateEmbedding(any(), taskType: any(named: 'taskType')))
          .thenAnswer((_) async => [1.0]);

      await service.embed('q', isDocument: true);
      await service.embed('q');

      verify(() => model.generateEmbedding('q', taskType: TaskType.retrievalDocument))
          .called(1);
      verify(() => model.generateEmbedding('q', taskType: TaskType.retrievalQuery))
          .called(1);
    });

    test('L2-normalizes a non-unit vector', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);
      when(() => model.generateEmbedding(any(), taskType: any(named: 'taskType')))
          .thenAnswer((_) async => [3.0, 4.0]); // norm = 5

      final vec = await service.embed('hello');

      expect(vec[0], closeTo(0.6, 1e-9));
      expect(vec[1], closeTo(0.8, 1e-9));
    });

    test('a zero vector is returned unchanged (no divide-by-zero)', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);
      when(() => model.generateEmbedding(any(), taskType: any(named: 'taskType')))
          .thenAnswer((_) async => [0.0, 0.0]);

      final vec = await service.embed('hello');

      expect(vec, [0.0, 0.0]);
    });

    test('a generateEmbedding failure degrades to [], not a throw', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);
      when(() => model.generateEmbedding(any(), taskType: any(named: 'taskType')))
          .thenThrow(Exception('inference crashed'));

      final vec = await service.embed('hello');

      expect(vec, isEmpty);
    });
  });

  group('dispose', () {
    test('closes the model and resets isReady to false', () async {
      when(() => gateway.hasActiveEmbedder()).thenReturn(true);
      final model = _MockEmbeddingModel();
      when(() => gateway.getActiveEmbedder(preferredBackend: any(named: 'preferredBackend')))
          .thenAnswer((_) async => model);
      when(() => model.close()).thenAnswer((_) async {});
      await service.init();

      await service.dispose();

      verify(() => model.close()).called(1);
      expect(service.isReady, isFalse);
    });

    test('is a no-op when nothing was ever loaded', () async {
      await service.dispose();

      expect(service.isReady, isFalse);
    });
  });
}
