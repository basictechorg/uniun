import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/gateway/subscriptions/sync_window.dart';

void main() {
  test('kRecentSyncWindow is 7 days', () {
    expect(kRecentSyncWindow, const Duration(days: 7));
  });

  test('recentSyncSinceEpochSeconds returns now minus the given window', () {
    for (final window in const [Duration(days: 7), Duration(days: 60)]) {
      final expected =
          DateTime.now().subtract(window).millisecondsSinceEpoch ~/ 1000;
      final actual = recentSyncSinceEpochSeconds(window);
      expect((actual - expected).abs(), lessThan(5), reason: 'window=$window');
    }
  });

  test('passing kRecentSyncWindow yields ~now minus that window', () {
    final expected =
        DateTime.now().subtract(kRecentSyncWindow).millisecondsSinceEpoch ~/
            1000;
    expect((recentSyncSinceEpochSeconds(kRecentSyncWindow) - expected).abs(),
        lessThan(5));
  });
}
