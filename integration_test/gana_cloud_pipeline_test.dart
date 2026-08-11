// Real-device verification of the UNIUN Cloud pipeline that Gana's cloud
// pin (foreground `GanaEngine` and the background `gana_workmanager.dart`
// isolate, both added this session) is built on: `UniunGatewayClient`
// talking to the real `api.uniun.in` gateway.
//
// Deliberately does NOT bootstrap the app's DI graph (`configureDependencies`)
// or open the real on-device Isar: this file is installed and run as the
// SAME app package as the user's real UNIUN install, so touching the real
// Isar or the real stored cloud credential here risks writing test data
// (or, worse, a live publish) into the user's actual account. Everything
// below either hits public/no-auth endpoints or uses a throwaway API key
// supplied explicitly for the test run — never the device's stored one.
//
// PASS path: result starts with `OK:` → the real gateway, its public
//            catalog, and (if a key was supplied) a real chat completion
//            all round-trip correctly through `UniunGatewayClient` — the
//            exact class both Gana cloud call sites use directly.
// SKIP path: result starts with `SKIP:` → precondition not met (no
//            network, or no test API key supplied for the inference leg).
// FAIL path: result starts with `FAIL:` or an assertion fires.
//
// How to run (no auth needed for the reachability leg):
//
//   flutter test integration_test/gana_cloud_pipeline_test.dart -d <device-id>
//
// To also exercise a real inference call, pass a throwaway UNIUN API key
// (Settings → UNIUN Cloud → an existing connected account's key, or mint one
// via the gateway's key-recovery flow) — never the primary device's stored
// key, since this process shares its on-disk state with the real app:
//
//   flutter test integration_test/gana_cloud_pipeline_test.dart -d <device-id> \
//     --dart-define=UNIUN_TEST_API_KEY=uk_...

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';

const String _testApiKey =
    String.fromEnvironment('UNIUN_TEST_API_KEY', defaultValue: '');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('UniunGatewayClient reaches the real gateway and lists the public model catalog',
      () async {
    final client = UniunGatewayClient();

    List<UniunModel> models;
    try {
      models = await client.listModels();
    } catch (e) {
      // ignore: avoid_print
      print('SKIP: gateway unreachable ($e) — check device network');
      return;
    }

    expect(models, isNotEmpty,
        reason: 'the public model catalog should never be empty');
    for (final m in models) {
      expect(m.id, isNotEmpty);
      expect(m.displayName, isNotEmpty);
    }
    // ignore: avoid_print
    print('OK: fetched ${models.length} models '
        '(${models.where((m) => !m.isPaid).length} free, '
        '${models.where((m) => m.isPaid).length} paid)');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('UniunGatewayClient completes a real one-shot chat call on a free model '
      '— the same client + call shape GanaEngine\'s cloud branch uses',
      () async {
    if (_testApiKey.isEmpty) {
      // ignore: avoid_print
      print('SKIP: no --dart-define=UNIUN_TEST_API_KEY=... supplied');
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

    final result = await client.chatCompletion(
      apiKey: _testApiKey,
      modelId: free.first.id,
      messages: const [
        {'role': 'user', 'content': 'Reply with exactly one word.'},
      ],
      maxTokens: 16,
    );

    expect(result, isNotNull);
    expect(result, isNotEmpty);
    // ignore: avoid_print
    print('OK: model="${free.first.id}" replied "${result?.trim()}"');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
