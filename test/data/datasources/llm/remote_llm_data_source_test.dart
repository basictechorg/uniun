import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/data/datasources/llm/llm_preferences_data_source.dart';
import 'package:uniun/data/datasources/llm/remote_llm_data_source.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
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

  group('hasActiveModel', () {
    test('not connected to UNIUN Cloud — false, never checks the model id',
        () async {
      when(() => uniun.isConnected()).thenAnswer((_) async => false);

      expect(await ds.hasActiveModel(), isFalse);
    });

    test('connected but no active cloud model id — false', () async {
      when(() => uniun.isConnected()).thenAnswer((_) async => true);
      when(() => prefs.activeCloudModelId).thenReturn(null);

      expect(await ds.hasActiveModel(), isFalse);
    });

    test('connected with an active cloud model id — true', () async {
      when(() => uniun.isConnected()).thenAnswer((_) async => true);
      when(() => prefs.activeCloudModelId).thenReturn('m');

      expect(await ds.hasActiveModel(), isTrue);
    });
  });

  group('openConversation / closeConversation', () {
    test('both are stateless no-ops that always succeed', () async {
      expect(await ds.openConversation(), const Right<Object, Unit>(unit));
      expect(await ds.closeConversation(), const Right<Object, Unit>(unit));
    });
  });

  group('listAvailableModels', () {
    test('delegates straight to UniunRepository', () async {
      when(() => uniun.listAvailableModels())
          .thenAnswer((_) async => const Right(<LlmModelInfo>[]));

      final result = await ds.listAvailableModels();

      expect(result, const Right<Object, List<LlmModelInfo>>([]));
      verify(() => uniun.listAvailableModels()).called(1);
    });
  });

  group('resumeBackgroundWork', () {
    test('is a stateless no-op that always succeeds', () async {
      expect(await ds.resumeBackgroundWork(), const Right<Object, Unit>(unit));
    });
  });

  group('sendChat', () {
    test('no active cloud model throws a clear exception before ever '
        'calling the gateway, whose message IS the human-readable text',
        () async {
      when(() => prefs.activeCloudModelId).thenReturn(null);

      try {
        await ds.sendChat(message: 'hi').toList();
        fail('expected an exception');
      } catch (e) {
        expect(
          e.toString(),
          'No cloud model selected. Pick one from the chat input picker.',
        );
      }
    });

    test('builds the OpenAI-shaped message list: system + history pairs + '
        'the current message, in order', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
          )).thenAnswer((_) => Stream.fromIterable(['ok']));

      await ds
          .sendChat(
            message: 'current question',
            systemInstruction: 'persona',
            cleanHistory: const [('q1', 'a1'), ('q2', 'a2')],
          )
          .toList();

      final captured = verify(() => uniun.streamChat(
            modelId: 'm',
            messages: captureAny(named: 'messages'),
          )).captured.single as List<Map<String, String>>;
      expect(captured, [
        {'role': 'system', 'content': 'persona'},
        {'role': 'user', 'content': 'q1'},
        {'role': 'assistant', 'content': 'a1'},
        {'role': 'user', 'content': 'q2'},
        {'role': 'assistant', 'content': 'a2'},
        {'role': 'user', 'content': 'current question'},
      ]);
    });

    test('a null/empty systemInstruction omits the system message entirely',
        () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
          )).thenAnswer((_) => Stream.fromIterable(['ok']));

      await ds.sendChat(message: 'hi').toList();

      final captured = verify(() => uniun.streamChat(
            modelId: 'm',
            messages: captureAny(named: 'messages'),
          )).captured.single as List<Map<String, String>>;
      expect(captured, [
        {'role': 'user', 'content': 'hi'},
      ]);
    });

    test('streams every token from the gateway through unchanged', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
          )).thenAnswer((_) => Stream.fromIterable(['a', 'b', 'c']));

      final tokens = await ds.sendChat(message: 'hi').toList();

      expect(tokens, ['a', 'b', 'c']);
    });

    test('a stream error rethrows to the caller after logging', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
          )).thenAnswer((_) => Stream<String>.error(Exception('gateway down')));

      await expectLater(
        ds.sendChat(message: 'hi'),
        emitsError(isA<Exception>()),
      );
    });

    test('cancels any in-flight extractions before starting, even when '
        'there are none (no-op)', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
          )).thenAnswer((_) => Stream.fromIterable(['ok']));

      final tokens = await ds.sendChat(message: 'hi').toList();

      expect(tokens, ['ok']);
    });
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

    // A genuine stream error now surfaces as Left(Failure), NOT Right(null)
    // — distinct from a cooperative cancel (see the concurrency group
    // below). This matters because GanaEngine._runOnce already branches on
    // this: Left → GanaRunStatus.failed (with the real error), Right(null)
    // → GanaRunStatus.skipped(modelSwapped). Previously both cases read as
    // Right(null), so a real cloud failure was silently miscategorized as
    // "preempted".
    test('a genuine stream error surfaces as Left, not Right(null)', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer(
        (_) => Stream<String>.error(Exception('gateway 500')),
      );

      final result = await ds.generateOneShot(prompt: 'hello');

      expect(result.isLeft(), isTrue);
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

  group('concurrency — independent in-flight calls', () {
    test('two concurrent calls both complete independently; neither blocks '
        'or cancels the other', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      final controllerA = StreamController<String>();
      final controllerB = StreamController<String>();
      var callCount = 0;
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) {
        callCount++;
        return callCount == 1 ? controllerA.stream : controllerB.stream;
      });

      final futureA = ds.generateOneShot(prompt: 'A');
      final futureB = ds.generateOneShot(prompt: 'B');
      await Future<void>.delayed(Duration.zero);

      controllerA.add('alpha');
      await controllerA.close();
      controllerB.add('beta');
      await controllerB.close();

      final resultA = await futureA;
      final resultB = await futureB;

      resultA.fold((_) => fail('expected Right'), (v) => expect(v, 'alpha'));
      resultB.fold((_) => fail('expected Right'), (v) => expect(v, 'beta'));
    });

    test('one call finishing normally does not affect a second, still '
        'in-flight call', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      final controllerA = StreamController<String>();
      final controllerB = StreamController<String>();
      var callCount = 0;
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) {
        callCount++;
        return callCount == 1 ? controllerA.stream : controllerB.stream;
      });

      final futureA = ds.generateOneShot(prompt: 'A');
      final futureB = ds.generateOneShot(prompt: 'B');
      await Future<void>.delayed(Duration.zero);

      // A finishes first; B is still open.
      controllerA.add('alpha');
      await controllerA.close();
      final resultA = await futureA;
      resultA.fold((_) => fail('expected Right'), (v) => expect(v, 'alpha'));

      // B is unaffected by A's completion.
      controllerB.add('beta');
      await controllerB.close();
      final resultB = await futureB;
      resultB.fold((_) => fail('expected Right'), (v) => expect(v, 'beta'));
    });

    test('starting a chat cancels all pending one-shot calls — each '
        'resolves as Right(null) instead of hanging', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
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

      final futureA = ds.generateOneShot(prompt: 'A');
      final futureB = ds.generateOneShot(prompt: 'B');
      await Future<void>.delayed(Duration.zero);

      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) => Stream.fromIterable(['chat reply']));

      final chatTokens = await ds.sendChat(message: 'hi').toList();

      final resultA = await futureA;
      final resultB = await futureB;

      resultA.fold((_) => fail('expected Right'), (v) => expect(v, isNull));
      resultB.fold((_) => fail('expected Right'), (v) => expect(v, isNull));
      expect(chatTokens, ['chat reply']);
    });

    test('preemptBackgroundWork cancels all pending one-shot calls the same '
        'way', () async {
      when(() => prefs.activeCloudModelId).thenReturn('m');
      final controllerA = StreamController<String>();
      when(() => uniun.streamChat(
            modelId: any(named: 'modelId'),
            messages: any(named: 'messages'),
            maxTokens: any(named: 'maxTokens'),
          )).thenAnswer((_) => controllerA.stream);

      final futureA = ds.generateOneShot(prompt: 'A');
      await Future<void>.delayed(Duration.zero);

      final preemptResult = await ds.preemptBackgroundWork();

      final resultA = await futureA;
      expect(preemptResult.isRight(), isTrue);
      resultA.fold((_) => fail('expected Right'), (v) => expect(v, isNull));
    });
  });
}
