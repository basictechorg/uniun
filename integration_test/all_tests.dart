// Aggregator entry point for ALL device-bound integration tests.
//
// Why this file exists: `flutter test integration_test/` installs the app
// FRESH per test file. If `flutter_gemma_bg_isolate_test.dart` needs a
// downloaded model and the next file reinstalls the APK, the model is gone
// → every subsequent test SKIPs. Running this aggregator instead bundles
// every test file's `main()` into a single app launch, so the model (and
// any other on-device state) persists across the whole suite.
//
// Run with:
//   flutter test integration_test/all_tests.dart -d <device-id>
//
// To add a new device-bound test: drop a `*_test.dart` file in this folder
// AND add an import + main() call below. (Yes it's manual — there is no
// glob in Dart imports. The list is the source of truth.)

import 'package:integration_test/integration_test.dart';

import 'flutter_gemma_bg_isolate_test.dart' as flutter_gemma_bg_isolate_test;
import 'scheduler_preemption_test.dart' as scheduler_preemption_test;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  flutter_gemma_bg_isolate_test.main();
  scheduler_preemption_test.main();
}
