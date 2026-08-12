import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/llm_preferences_data_source.dart';
import 'package:uniun/data/datasources/llm/local_llm_data_source.dart';
import 'package:uniun/data/datasources/llm/remote_llm_data_source.dart';
import 'package:uniun/data/repositories/llm_repository_impl.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';
import 'package:uniun/domain/repositories/ai_model_repository.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';

class _MockLocal extends Mock implements LocalLlmDataSource {}

class _MockRemote extends Mock implements RemoteLlmDataSource {}

class _MockPrefs extends Mock implements LlmPreferencesDataSource {}

class _MockCloudAuth extends Mock implements UniunRepository {}

class _MockLocalSettings extends Mock implements AppSettingsStore {}

class _MockLocalCatalog extends Mock implements AIModelRepository {}

/// Covers: [LlmRepositoryImpl.generateOneShot] dispatch — default routing
/// follows the globally-active backend; `backendOverride` bypasses it
/// (Gana's per-agent cloud pin) without touching global preference reads;
/// `modelIdOverride` passes through to the chosen data source untouched.
void main() {
  setUpAll(() {
    registerFallbackValue(LlmTaskKind.extract);
    registerFallbackValue(AIModelId.qwen25_05b);
  });

  late _MockLocal local;
  late _MockRemote remote;
  late _MockPrefs prefs;
  late _MockLocalSettings localSettings;
  late _MockLocalCatalog localCatalog;
  late LlmRepositoryImpl repo;

  setUp(() {
    local = _MockLocal();
    remote = _MockRemote();
    prefs = _MockPrefs();
    localSettings = _MockLocalSettings();
    localCatalog = _MockLocalCatalog();
    repo = LlmRepositoryImpl(
      local,
      remote,
      prefs,
      _MockCloudAuth(),
      localSettings,
      localCatalog,
    );

    when(() => local.generateOneShot(
          prompt: any(named: 'prompt'),
          maxTokens: any(named: 'maxTokens'),
          kind: any(named: 'kind'),
          modelIdOverride: any(named: 'modelIdOverride'),
        )).thenAnswer((_) async => const Right('local reply'));
    when(() => remote.generateOneShot(
          prompt: any(named: 'prompt'),
          maxTokens: any(named: 'maxTokens'),
          kind: any(named: 'kind'),
          modelIdOverride: any(named: 'modelIdOverride'),
        )).thenAnswer((_) async => const Right('cloud reply'));
  });

  group('no override — follows the global active backend', () {
    test('activeBackend=local routes to LocalLlmDataSource', () async {
      when(() => prefs.activeBackend).thenReturn(LlmBackendType.localGemma);

      final result = await repo.generateOneShot(prompt: 'hi');

      expect(result, const Right('local reply'));
      verify(() => local.generateOneShot(
            prompt: 'hi',
            maxTokens: 1024,
            kind: LlmTaskKind.extract,
            modelIdOverride: null,
          )).called(1);
      verifyNever(() => remote.generateOneShot(
            prompt: any(named: 'prompt'),
            maxTokens: any(named: 'maxTokens'),
            kind: any(named: 'kind'),
            modelIdOverride: any(named: 'modelIdOverride'),
          ));
    });

    test('activeBackend=uniunCloud routes to RemoteLlmDataSource', () async {
      when(() => prefs.activeBackend).thenReturn(LlmBackendType.uniunCloud);

      final result = await repo.generateOneShot(prompt: 'hi');

      expect(result, const Right('cloud reply'));
      verify(() => remote.generateOneShot(
            prompt: 'hi',
            maxTokens: 1024,
            kind: LlmTaskKind.extract,
            modelIdOverride: null,
          )).called(1);
      verifyNever(() => local.generateOneShot(
            prompt: any(named: 'prompt'),
            maxTokens: any(named: 'maxTokens'),
            kind: any(named: 'kind'),
            modelIdOverride: any(named: 'modelIdOverride'),
          ));
    });
  });

  group('backendOverride bypasses the global preference', () {
    test('backendOverride=uniunCloud routes to remote even when the global '
        'active backend is local (Gana per-agent cloud pin)', () async {
      when(() => prefs.activeBackend).thenReturn(LlmBackendType.localGemma);

      final result = await repo.generateOneShot(
        prompt: 'summarize',
        kind: LlmTaskKind.gana,
        backendOverride: LlmBackendType.uniunCloud,
        modelIdOverride: 'claude-cloud-mini',
      );

      expect(result, const Right('cloud reply'));
      verify(() => remote.generateOneShot(
            prompt: 'summarize',
            maxTokens: 1024,
            kind: LlmTaskKind.gana,
            modelIdOverride: 'claude-cloud-mini',
          )).called(1);
      verifyNever(() => local.generateOneShot(
            prompt: any(named: 'prompt'),
            maxTokens: any(named: 'maxTokens'),
            kind: any(named: 'kind'),
            modelIdOverride: any(named: 'modelIdOverride'),
          ));
      // The override path never even reads the global preference.
      verifyNever(() => prefs.activeBackend);
    });

    test('backendOverride=localGemma routes to local even when the global '
        'active backend is cloud', () async {
      when(() => prefs.activeBackend).thenReturn(LlmBackendType.uniunCloud);

      final result = await repo.generateOneShot(
        prompt: 'summarize',
        backendOverride: LlmBackendType.localGemma,
      );

      expect(result, const Right('local reply'));
      verify(() => local.generateOneShot(
            prompt: 'summarize',
            maxTokens: 1024,
            kind: LlmTaskKind.extract,
            modelIdOverride: null,
          )).called(1);
    });
  });

  group('setActiveModel — local (issue #160 regression: switching between '
      'two already-downloaded models must re-link flutter_gemma, not just '
      'write settings)', () {
    setUp(() {
      when(() => prefs.activeBackend).thenReturn(LlmBackendType.localGemma);
      when(() => localSettings.setActiveModelId(any()))
          .thenAnswer((_) async {});
    });

    test('writes the settings id AND calls activateModel — a plain settings '
        'write alone leaves flutter_gemma pointed at the previous model',
        () async {
      when(() => localCatalog.activateModel(AIModelId.gemma4E2b))
          .thenAnswer((_) async => const Right(unit));

      final result = await repo.setActiveModel('gemma4E2b');

      expect(result.isRight(), isTrue);
      verify(() => localSettings.setActiveModelId(AIModelId.gemma4E2b))
          .called(1);
      verify(() => localCatalog.activateModel(AIModelId.gemma4E2b)).called(1);
    });

    test('an unknown model id fails before touching settings or the catalog',
        () async {
      final result = await repo.setActiveModel('not-a-real-model');

      expect(result.isLeft(), isTrue);
      verifyNever(() => localSettings.setActiveModelId(any()));
      verifyNever(() => localCatalog.activateModel(any()));
    });

    test('activateModel failure (e.g. the picked model was never actually '
        'downloaded) surfaces as a Left, even though settings already wrote',
        () async {
      when(() => localCatalog.activateModel(AIModelId.deepseekR1)).thenAnswer(
          (_) async => const Left(Failure.errorFailure('not downloaded')));

      final result = await repo.setActiveModel('deepseekR1');

      expect(result.isLeft(), isTrue);
      verify(() => localSettings.setActiveModelId(AIModelId.deepseekR1))
          .called(1);
    });

    test('cloud backend never touches the local catalog at all', () async {
      when(() => prefs.activeBackend).thenReturn(LlmBackendType.uniunCloud);
      when(() => prefs.setActiveCloudModelId(any())).thenAnswer((_) async {});

      final result = await repo.setActiveModel('claude-sonnet-5');

      expect(result.isRight(), isTrue);
      verifyNever(() => localCatalog.activateModel(any()));
      verifyNever(() => localSettings.setActiveModelId(any()));
    });
  });
}
