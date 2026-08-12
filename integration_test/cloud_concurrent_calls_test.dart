// Real-device verification that the UNIUN Cloud gateway itself supports
// two concurrent chat completions from the same account (issue #160
// follow-on — see docs/SHIVA/scheduling.md §8, "Cloud one-shot
// concurrency"). The app-side Dart logic fix (RemoteLlmDataSource
// tracking each call independently instead of a single shared
// subscription) is a pure control-flow change with no platform/native
// dependency — it's already fully verified by the plain host-VM suite:
//   test/data/datasources/llm/remote_llm_data_source_test.dart
//   test/integration/llm_cloud_concurrency_flow_test.dart
// This device test's job is narrower and complementary: prove the real
// gateway doesn't itself serialize or reject a second in-flight stream
// from one API key, which the app-side fix depends on being true.
//
// maxTokens is 1024 to match GenerateOneShotInput's real production
// default (lib/domain/usecases/llm_usecases.dart) — the same budget
// GanaEngine's cloud call actually uses. An earlier version of this file
// used 16-32 tokens to keep the call "cheap", which produced empty
// completions from a real model on-device; that was this test starving
// the model of the headroom it needs, not a gateway or app bug (see
// docs/AUDIT.md for the full trace of that investigation).
//
// Uses the REAL app DI graph and the REAL stored UNIUN Cloud credential
// on this device (`LlmCredentialsDataSource.getUniunApiKey()`) — run only
// against a device that's already connected to UNIUN Cloud (Settings →
// UNIUN Cloud), which this test assumes rather than provisions. If
// nothing is connected, it SKIPs rather than fabricating a connection.
//
// PASS path: result starts with `OK:` → both concurrent completions
//            returned real, non-empty text.
// SKIP path: result starts with `SKIP:` → no identity or no UNIUN Cloud
//            connection on this device.
// FAIL path: result starts with `FAIL:` or an assertion fires.
//
// How to run:
//
//   flutter test integration_test/cloud_concurrent_calls_test.dart -d <device-id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';

const int _kProductionMaxTokens = 1024; // matches GenerateOneShotInput default

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'two concurrent chatCompletion calls on the same real, already-'
    'connected device account both complete independently',
    () async {
      await configureDependencies();

      final keys = await getIt<UserRepository>().getActiveKeysHex();
      if (keys == null) {
        // ignore: avoid_print
        print('SKIP: no active identity on this device');
        return;
      }

      final connected = await getIt<IsUniunCloudConnectedUseCase>().call();
      if (!connected) {
        // ignore: avoid_print
        print('SKIP: UNIUN Cloud not connected on this device — connect '
            'via Settings first');
        return;
      }

      final apiKey = await getIt<LlmCredentialsDataSource>().getUniunApiKey();
      if (apiKey == null) {
        // ignore: avoid_print
        print('SKIP: connected but no stored API key found');
        return;
      }

      final client = UniunGatewayClient();
      final models = await client.listModels();
      final free = models.where((m) => !m.isPaid).toList();
      if (free.isEmpty) {
        // ignore: avoid_print
        print('SKIP: no free-tier model on the public catalog to test against');
        return;
      }
      final modelId = free.first.id;
      // ignore: avoid_print
      print('using model=$modelId, maxTokens=$_kProductionMaxTokens');

      // Two DIFFERENT UniunGatewayClient instances (never sharing an
      // http.Client), fired without awaiting the first — genuinely
      // concurrent, not sequential.
      final clientA = UniunGatewayClient();
      final clientB = UniunGatewayClient();
      final futureA = clientA.chatCompletion(
        apiKey: apiKey,
        modelId: modelId,
        messages: const [
          {'role': 'user', 'content': 'What is 7 plus 5? Answer in one word.'},
        ],
        maxTokens: _kProductionMaxTokens,
      );
      final futureB = clientB.chatCompletion(
        apiKey: apiKey,
        modelId: modelId,
        messages: const [
          {'role': 'user', 'content': 'What color is the sky on a clear day? Answer in one word.'},
        ],
        maxTokens: _kProductionMaxTokens,
      );

      final results = await Future.wait([futureA, futureB]);
      // ignore: avoid_print
      print('concurrent results (separate clients): A="${results[0]}" '
          'B="${results[1]}"');

      expect(results[0], isNotNull);
      expect(results[0], isNotEmpty);
      expect(results[1], isNotNull);
      expect(results[1], isNotEmpty);

      // ignore: avoid_print
      print('OK: two concurrent calls (separate clients) returned non-empty '
          'text independently, using the real device account (model=$modelId)');
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
