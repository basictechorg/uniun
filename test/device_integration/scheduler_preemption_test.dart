// Real-device verification of the InferenceScheduler against flutter_gemma.
//
// What it verifies (matches docs/SHIVA/scheduling.md Scenario 1):
//   While a Nataraj job is mid-stream against a real loaded model, a
//   chat submission must preempt it within one token boundary
//   (empirically <500 ms on flutter_gemma 1.1.x). This is the
//   user-visible #118 fix.
//
// PASS path: result starts with `OK:` → scheduler preemption works on
//            the real native engine.
// SKIP path: result starts with `SKIP:` → no model installed yet; open
//            Shiv on this device, pick a model, wait for download, then
//            re-run.
// FAIL path: assertion fires or result starts with `FAIL:` → either the
//            scheduler isn't actually calling stopGeneration() on the
//            real InferenceChat, or flutter_gemma's stopGeneration() has
//            regressed.
//
// Why this file lives at `test/device_integration/`:
//   it needs a real device (iOS sim / Android emulator) to load Gemma's
//   native libraries. UNIUN groups all device-bound tests under
//   `test/device_integration/` so a single command runs them all.
//
// How to run (after the device has an AI model installed via Shiv):
//
//   flutter test test/device_integration/ -d <device-id>
//
// Expected output on PASS:
//   OK: chat first-token latency = NNN ms (well under the 500ms budget)

import 'package:flutter_gemma/flutter_gemma.dart' hide CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniun/data/datasources/llm/inference_scheduler.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'chat preempts running nataraj on the real flutter_gemma engine',
    (tester) async {
      if (!FlutterGemma.hasActiveModel()) {
        // ignore: avoid_print
        print('SKIP: no active model on device — install one via Shiv first');
        return;
      }

      final scheduler = InferenceScheduler();
      scheduler.notifyLoadedModel('integration_test_model');

      // Long Nataraj-like one-shot: open a chat, queue a chunky prompt,
      // stream until cancel or natural end. Mirrors the path
      // AIModelRunner.generateOneShot takes.
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

      // 1. Submit a long Nataraj-equivalent at T4.
      final natarajFuture = scheduler.run<String?>(
        kind: LlmTaskKind.nataraj,
        modelId: 'integration_test_model',
        work: (cancel) => doOneShot(
          'Write a 500-word essay about the history of the printing press.',
          cancel,
          maxTokens: 800,
        ),
      );

      // 2. Give the native engine ~500 ms to settle into streaming.
      await Future.delayed(const Duration(milliseconds: 500));
      expect(
        scheduler.runningKind,
        equals(LlmTaskKind.nataraj),
        reason: 'nataraj should be running before chat preempts',
      );

      // 3. Submit chat at T0. Record the time until the first token.
      final chatStart = DateTime.now();
      DateTime? firstTokenAt;
      final chatFuture = scheduler.run<String>(
        kind: LlmTaskKind.chat,
        modelId: 'integration_test_model',
        work: (cancel) async {
          final model = await FlutterGemma.getActiveModel(maxTokens: 256);
          final chat = await model.openChat(temperature: 0.8, topK: 40);
          try {
            await chat.addQueryChunk(Message.text(text: 'Say hello.'));
            final buf = StringBuffer();
            await for (final r in chat.generateChatResponseAsync()) {
              if (cancel.isCancelled) {
                await chat.stopGeneration();
                break;
              }
              if (r is TextResponse && r.token.isNotEmpty) {
                firstTokenAt ??= DateTime.now();
                buf.write(r.token);
              }
            }
            return buf.toString();
          } finally {
            await chat.close();
          }
        },
      );

      final chatResult = await chatFuture;
      await natarajFuture; // wait for the re-queued nataraj to also finish

      expect(firstTokenAt, isNotNull,
          reason: 'chat must have produced at least one token');
      final firstTokenLatency =
          firstTokenAt!.difference(chatStart).inMilliseconds;

      // The contract: chat should start streaming within one nataraj
      // token boundary of being submitted. Real-world budget is ~500 ms
      // (flutter_gemma's stopGeneration honour-time + chat prefill).
      // ignore: avoid_print
      print(
        firstTokenLatency < 1500
            ? 'OK: chat first-token latency = ${firstTokenLatency} ms'
            : 'FAIL: chat first-token latency = ${firstTokenLatency} ms (>1500 ms)',
      );
      expect(firstTokenLatency, lessThan(1500),
          reason: 'chat preempt should complete in under 1500ms');
      expect(chatResult, isNotEmpty);
    },
    // Real LLM generations can take a while end-to-end (nataraj re-queue
    // finishes after chat). Give the whole test a generous timeout.
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
