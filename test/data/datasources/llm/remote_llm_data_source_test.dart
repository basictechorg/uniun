import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/data/datasources/llm/llm_preferences_data_source.dart';
import 'package:uniun/data/datasources/llm/remote_llm_data_source.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';

class _MockUniun extends Mock implements UniunRepository {}

class _MockPrefs extends Mock implements LlmPreferencesDataSource {}

/// Covers: [RemoteLlmDataSource.generateOneShot] model resolution —
/// `modelIdOverride` wins over the global active cloud model id (Gana's
/// per-agent cloud pin, via `LlmRepositoryImpl`'s backend override), falls
/// back to the global pref when absent, and short-circuits when neither is
/// set.
void main() {
  late _MockUniun uniun;
  late _MockPrefs prefs;
  late RemoteLlmDataSource ds;

  setUp(() {
    uniun = _MockUniun();
    prefs = _MockPrefs();
    ds = RemoteLlmDataSource(uniun, prefs);
  });

  group('model resolution', () {
    test('modelIdOverride is used even when a different model is globally active',
        () async {
      when(() => prefs.activeCloudModelId).thenReturn('global-model');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) => Stream.fromIterable(['hi', ' there']));

      final result = await ds.generateOneShot(
        prompt: 'hello',
        modelIdOverride: 'gana-pinned-model',
      );

      expect(result, isNotNull);
      result.fold((_) => fail('expected Right'), (v) => expect(v, 'hi there'));
      verify(() => uniun.streamChat(
            modelId: 'gana-pinned-model',
            messages: [
              {'role': 'user', 'content': 'hello'},
            ],
            maxTokens: 1024,
          )).called(1);
    });

    test('falls back to the globally active cloud model when no override is given',
        () async {
      when(() => prefs.activeCloudModelId).thenReturn('global-model');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) => Stream.fromIterable(['ok']));

      await ds.generateOneShot(prompt: 'hello');

      verify(() => uniun.streamChat(
            modelId: 'global-model',
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).called(1);
    });

    test('no override and no active cloud model → Right(null), never calls the gateway',
        () async {
      when(() => prefs.activeCloudModelId).thenReturn(null);

      final result = await ds.generateOneShot(prompt: 'hello');

      result.fold((_) => fail('expected Right'), (v) => expect(v, isNull));
      verifyNever(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          ));
    });
  });

  group('stream outcome', () {
    test('accumulates every token into one string', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) => Stream.fromIterable(['The ', 'quick ', 'fox']));

      final result = await ds.generateOneShot(prompt: 'hello');

      result.fold((_) => fail('expected Right'), (v) => expect(v, 'The quick fox'));
    });

    // Current behaviour: a mid-stream error resolves to `Right(null)`, not a
    // `Left(Failure)` — the completer's onError path swallows it so a flaky
    // gateway response reads the same as "model produced nothing" rather
    // than a hard failure.
    test('a stream error resolves to Right(null), not Left', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer(
        (_) => Stream<String>.error(Exception('gateway 500')),
      );

      final result = await ds.generateOneShot(prompt: 'hello');

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (v) => expect(v, isNull));
    });

    test('an empty stream resolves to Right("")', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) => const Stream<String>.empty());

      final result = await ds.generateOneShot(prompt: 'hello');

      result.fold((_) => fail('expected Right'), (v) => expect(v, ''));
    });
  });
}
