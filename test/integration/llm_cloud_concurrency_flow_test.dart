import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/llm_preferences_data_source.dart';
import 'package:uniun/data/datasources/llm/local_llm_data_source.dart';
import 'package:uniun/data/datasources/llm/remote_llm_data_source.dart';
import 'package:uniun/data/repositories/llm_repository_impl.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/repositories/ai_model_repository.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';

class _MockUniun extends Mock implements UniunRepository {}

class _MockLocal extends Mock implements LocalLlmDataSource {}

class _MockLocalSettings extends Mock implements AppSettingsStore {}

class _MockLocalCatalog extends Mock implements AIModelRepository {}

/// Vertical-slice integration test — wires the REAL `LlmRepositoryImpl`,
/// `RemoteLlmDataSource`, and `LlmPreferencesDataSource` (backed by real,
/// mocked-platform-channel `SharedPreferences`) together, with only the
/// true external boundary (`UniunRepository` — the HTTP gateway) and the
/// untouched local path doubled. Confirms the cloud concurrency fix
/// (issue #160 follow-on) holds through the real dispatch chain, not just
/// against `RemoteLlmDataSource` constructed directly (see the isolated
/// unit tests in `test/data/datasources/llm/remote_llm_data_source_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockUniun uniun;
  late LlmPreferencesDataSource prefs;
  late RemoteLlmDataSource remote;
  late LlmRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    uniun = _MockUniun();
    prefs = LlmPreferencesDataSource(await SharedPreferences.getInstance());
    remote = RemoteLlmDataSource(uniun, prefs);
    repo = LlmRepositoryImpl(
      _MockLocal(),
      remote,
      prefs,
      uniun,
      _MockLocalSettings(),
      _MockLocalCatalog(),
    );
    await prefs.setActiveBackend(LlmBackendType.uniunCloud);
    await prefs.setActiveCloudModelId('cloud-model');
  });

  test('two concurrent generateOneShot calls through the real repository '
      'dispatch chain both complete independently', () async {
    var callCount = 0;
    when(() => uniun.streamChat(
          modelId: any(named: 'modelId'),
          messages: any(named: 'messages'),
          maxTokens: any(named: 'maxTokens'),
        )).thenAnswer((_) {
      callCount++;
      return callCount == 1
          ? Stream.fromIterable(['nataraj-bg'])
          : Stream.fromIterable(['nataraj-fg']);
    });

    final bg = repo.generateOneShot(prompt: 'background fill');
    final fg = repo.generateOneShot(prompt: 'foreground fill');

    final bgResult = await bg;
    final fgResult = await fg;

    bgResult.fold((_) => fail('expected Right'), (v) => expect(v, 'nataraj-bg'));
    fgResult.fold((_) => fail('expected Right'), (v) => expect(v, 'nataraj-fg'));
  });

  test('sendChat through the real repository cancels pending cloud '
      'generateOneShot calls instead of leaving them hanging', () async {
    final controllerA = StreamController<String>();
    final controllerB = StreamController<String>();
    var extractionCalls = 0;
    when(() => uniun.streamChat(
          modelId: any(named: 'modelId'),
          messages: any(named: 'messages'),
          maxTokens: any(named: 'maxTokens'),
        )).thenAnswer((_) {
      extractionCalls++;
      return extractionCalls == 1 ? controllerA.stream : controllerB.stream;
    });

    final futureA = repo.generateOneShot(prompt: 'A');
    final futureB = repo.generateOneShot(prompt: 'B');
    await Future<void>.delayed(Duration.zero);

    when(() => uniun.streamChat(
          modelId: any(named: 'modelId'),
          messages: any(named: 'messages'),
          maxTokens: any(named: 'maxTokens'),
        )).thenAnswer((_) => Stream.fromIterable(['chat reply']));

    final chatTokens = await repo
        .sendChat(message: 'hi', systemInstruction: null)
        .toList();

    final resultA = await futureA;
    final resultB = await futureB;

    resultA.fold((_) => fail('expected Right'), (v) => expect(v, isNull));
    resultB.fold((_) => fail('expected Right'), (v) => expect(v, isNull));
    expect(chatTokens, ['chat reply']);
  });

  test('a genuine cloud failure surfaces as Left through the full '
      'dispatch chain, not Right(null)', () async {
    when(() => uniun.streamChat(
          modelId: any(named: 'modelId'),
          messages: any(named: 'messages'),
          maxTokens: any(named: 'maxTokens'),
        )).thenAnswer((_) => Stream<String>.error(Exception('gateway 500')));

    final result = await repo.generateOneShot(prompt: 'hello');

    expect(result.isLeft(), isTrue);
  });
}
