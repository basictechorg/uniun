import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/local_llm_runner.dart';
import 'package:uniun/data/repositories/ai_model_repository_impl.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';

import '../../_helpers/fake_path_provider.dart';
import '../../_helpers/isar_test_harness.dart';

class _MockSettings extends Mock implements AppSettingsStore {}

class _MockRunner extends Mock implements AIModelRunner {}

/// Covers: AIModelRepositoryImpl.activateModel/deleteModel's orchestration
/// decisions — when they route through AIModelRunner's scheduler-coordinated
/// path, and with which forcePreempt value, vs. when they skip it entirely
/// (issue #160 follow-on: model-switch/delete must not race an in-flight
/// generation against the native engine).
///
/// `isModelInstalled`/`uninstallModel` are direct flutter_gemma statics with
/// no mockable seam, so this uses a REAL `FlutterGemma.initialize()` (with
/// mocked shared_preferences) rather than faking them — only
/// `AppSettingsStore`/`AIModelRunner` are doubled. Nothing is ever actually
/// downloaded in this environment, so `activateModel`'s SUCCESS path (which
/// requires `isModelInstalled` to return true) is not reachable here — only
/// its "not installed yet" failure path is exercised. `deleteModel`'s full
/// branching (active vs. non-active, forced routing, error propagation) is
/// fully covered, since it doesn't depend on anything being installed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(AIModelId.qwen25_05b);
    registerFallbackValue(() async {});
    registerFallbackValue(() async => const Right<Failure, Unit>(unit));
  });

  late Isar isar;
  late _MockSettings settings;
  late _MockRunner runner;
  late AIModelRepositoryImpl repo;
  late Directory tempDir;

  setUp(() async {
    isar = await openTestIsar();
    settings = _MockSettings();
    runner = _MockRunner();
    repo = AIModelRepositoryImpl(isar, settings, runner);

    tempDir = await Directory.systemTemp.createTemp('ai_model_repo_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(
      docs: tempDir.path,
      support: tempDir.path,
    );

    SharedPreferences.setMockInitialValues({});
    await FlutterGemma.initialize();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await tempDir.delete(recursive: true);
  });

  group('activateModel', () {
    test('a model that is not actually downloaded fails before ever '
        'reaching the runner', () async {
      final result = await repo.activateModel(AIModelId.gemma4E2b);

      expect(result.isLeft(), isTrue);
      verifyNever(() => runner.runExclusiveModelOperation<Either<Failure, Unit>>(
            forcePreempt: any(named: 'forcePreempt'),
            action: any(named: 'action'),
          ));
    });
  });

  group('deleteModel', () {
    test('deleting a model that is NOT the active one never touches the '
        'runner', () async {
      when(() => settings.activeModelId).thenReturn(AIModelId.gemma4E4b);

      final result = await repo.deleteModel(AIModelId.deepseekR1);

      expect(result.isRight(), isTrue);
      verifyNever(() => runner.runExclusiveModelOperation<void>(
            forcePreempt: any(named: 'forcePreempt'),
            action: any(named: 'action'),
          ));
      verifyNever(() => settings.setActiveModelId(any()));
    });

    test('deleting the currently-active model routes through the runner '
        'with forcePreempt:true, then clears the active setting', () async {
      when(() => settings.activeModelId).thenReturn(AIModelId.deepseekR1);
      when(() => settings.setActiveModelId(any())).thenAnswer((_) async {});
      when(() => runner.runExclusiveModelOperation<void>(
            forcePreempt: any(named: 'forcePreempt'),
            action: any(named: 'action'),
          )).thenAnswer((invocation) async {
        final action = invocation.namedArguments[#action] as Future<void>
            Function();
        await action();
      });

      final result = await repo.deleteModel(AIModelId.deepseekR1);

      expect(result.isRight(), isTrue);
      verify(() => runner.runExclusiveModelOperation<void>(
            forcePreempt: true,
            action: any(named: 'action'),
          )).called(1);
      verify(() => settings.setActiveModelId(null)).called(1);
    });

    // ── Negative ────────────────────────────────────────────────────────

    test('the runner rejecting the wrapped action surfaces as a Left, not '
        'silently swallowed', () async {
      when(() => settings.activeModelId).thenReturn(AIModelId.deepseekR1);
      when(() => runner.runExclusiveModelOperation<void>(
            forcePreempt: any(named: 'forcePreempt'),
            action: any(named: 'action'),
          )).thenThrow(Exception('scheduler blew up'));

      final result = await repo.deleteModel(AIModelId.deepseekR1);

      expect(result.isLeft(), isTrue);
      verifyNever(() => settings.setActiveModelId(any()));
    });

    test('deleting an unknown/never-installed model that happens to be '
        '"active" in settings still routes through the forced path '
        'harmlessly', () async {
      when(() => settings.activeModelId).thenReturn(AIModelId.qwen25_05b);
      when(() => settings.setActiveModelId(any())).thenAnswer((_) async {});
      when(() => runner.runExclusiveModelOperation<void>(
            forcePreempt: any(named: 'forcePreempt'),
            action: any(named: 'action'),
          )).thenAnswer((invocation) async {
        final action = invocation.namedArguments[#action] as Future<void>
            Function();
        await action();
      });

      final result = await repo.deleteModel(AIModelId.qwen25_05b);

      expect(result.isRight(), isTrue);
      verify(() => runner.runExclusiveModelOperation<void>(
            forcePreempt: true,
            action: any(named: 'action'),
          )).called(1);
    });
  });
}
