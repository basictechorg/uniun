// Real-device verification of the modelSwitch scheduler tier (issue #160
// follow-on — see docs/SHIVA/scheduling.md §3, "Model switch tier").
//
// What it verifies:
//   1. A gentle model-switch operation (forcePreempt:false) waits for a
//      real, currently-streaming generation to finish before running —
//      it must NOT call stopGeneration() on the in-flight session.
//   2. A forced model-switch operation (forcePreempt:true) cancels a
//      real, currently-streaming generation immediately, the same way
//      chat already does (scheduler_preemption_test.dart).
//
// This does not require a second downloaded model — the coordination
// being verified (wait-vs-preempt against the scheduler) is orthogonal
// to which model the `action` closure actually activates. The `action`
// closures below are trivial no-ops standing in for
// `AIModelRepositoryImpl.activateModel`/`deleteModel`'s real work, which
// is already covered by `test/data/repositories/ai_model_repository_impl_test.dart`
// (mocked `AIModelRunner`) — this file's job is only to prove the
// scheduler coordination itself holds against a REAL native generation,
// not to re-verify the native install/uninstall calls.
//
// PASS path: result starts with `OK:` → both gentle and forced ordering
//            held on the real native engine.
// SKIP path: result starts with `SKIP:` → no model installed yet; open
//            Shiv on this device, pick a model, wait for download, then
//            re-run.
// FAIL path: assertion fires — the modelSwitch tier's ordering guarantee
//            broke against a real generation.
//
// How to run (after the device has an AI model installed via Shiv):
//
//   flutter test integration_test/scheduler_model_switch_test.dart -d <device-id>

import 'package:flutter_gemma/flutter_gemma.dart' hide CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/inference_scheduler.dart';
import 'package:uniun/data/datasources/llm/local_llm_runner.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<String?> doOneShot(
    String prompt,
    CancelToken cancel, {
    int maxTokens = 256,
  }) async {
    final model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    final chat = await model.openChat(temperature: 0.8, topK: 40);
    try {
      await chat.addQueryChunk(Message.text(text: prompt));
      final buf = StringBuffer();
      await for (final r in chat.generateChatResponseAsync()) {
        if (cancel.isCancelled) {
          await chat.stopGeneration();
          break;
        }
        if (r is TextResponse) buf.write(r.token);
      }
      return buf.toString();
    } finally {
      await chat.close();
    }
  }

  testWidgets(
    'gentle model switch waits for a real generation to finish, forced '
    'switch preempts it immediately',
    (tester) async {
      if (!FlutterGemma.hasActiveModel()) {
        // ignore: avoid_print
        print('SKIP: no active model on device — install one via Shiv first');
        return;
      }

      final scheduler = InferenceScheduler();
      scheduler.notifyLoadedModel('integration_test_model');
      final settings = AppSettingsStore(await SharedPreferences.getInstance());
      final runner = AIModelRunner(scheduler, settings);

      // ── Part 1: gentle switch waits ──────────────────────────────────
      final order = <String>[];
      final natarajFuture = scheduler.run<String?>(
        kind: LlmTaskKind.nataraj,
        modelId: 'integration_test_model',
        work: (cancel) async {
          final r = await doOneShot(
            'Write a 200-word paragraph about the history of maps.',
            cancel,
            maxTokens: 400,
          );
          order.add('nataraj');
          return r;
        },
      );
      await Future.delayed(const Duration(milliseconds: 500));
      expect(scheduler.runningKind, equals(LlmTaskKind.nataraj),
          reason: 'nataraj should be running before the gentle switch arrives');

      final gentleSwitch = runner.runExclusiveModelOperation<void>(
        forcePreempt: false,
        action: () async => order.add('gentle-switch'),
      );
      await Future.wait([natarajFuture, gentleSwitch]);

      expect(order, ['nataraj', 'gentle-switch'],
          reason: 'gentle switch must not preempt the real generation');

      // ── Part 2: forced switch preempts ───────────────────────────────
      order.clear();
      final natarajFuture2 = scheduler.run<String?>(
        kind: LlmTaskKind.nataraj,
        modelId: 'integration_test_model',
        work: (cancel) async {
          final r = await doOneShot(
            'Write a 200-word paragraph about the history of bridges.',
            cancel,
            maxTokens: 400,
          );
          order.add('nataraj2');
          return r;
        },
      );
      await Future.delayed(const Duration(milliseconds: 500));
      expect(scheduler.runningKind, equals(LlmTaskKind.nataraj));

      final forcedSwitch = runner.runExclusiveModelOperation<void>(
        forcePreempt: true,
        action: () async => order.add('forced-switch'),
      );
      await forcedSwitch;
      await natarajFuture2; // re-queued run completes after the switch

      expect(order.first, equals('forced-switch'),
          reason: 'forced switch must preempt the real generation immediately');
      expect(order, contains('nataraj2'),
          reason: 're-queued nataraj must still complete after the switch');

      // ignore: avoid_print
      print('OK: gentle switch waited for the real generation to finish; '
          'forced switch preempted it immediately');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
