import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/gateway/orchestrator/relay_status_reporter.dart';
import 'package:uniun/gateway/transport/relay_connection.dart';

import '../../_helpers/isar_test_harness.dart';

/// Covers: RelayStatusReporter's ConnectionState→RelayStatus mapping for
/// every case (connected/connecting/disconnected), the lastConnectedAt
/// stamp on transition to connected (and that it's left untouched for the
/// other two states), and the no-matching-relay-row no-op.
void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<void> seedRelay(String url) {
    return isar.writeTxn(() async {
      await isar.relayModels.put(
        RelayModel()
          ..url = url
          ..read = true
          ..write = true
          ..status = RelayStatus.disconnected
          ..isSystem = false,
      );
    });
  }

  test('a report for a URL with no matching RelayModel is a no-op',
      () async {
    final reporter = RelayStatusReporter(isar);
    await expectLater(
      reporter.report('wss://ghost', ConnectionState.connected),
      completes,
    );
    expect(await isar.relayModels.where().count(), 0);
  });

  test('connected maps to RelayStatus.connected and stamps lastConnectedAt',
      () async {
    await seedRelay('wss://r1');
    final reporter = RelayStatusReporter(isar);

    await reporter.report('wss://r1', ConnectionState.connected);

    final row = await isar.relayModels.where().urlEqualTo('wss://r1').findFirst();
    expect(row!.status, RelayStatus.connected);
    expect(row.lastConnectedAt, isNotNull);
  });

  test('connecting maps to RelayStatus.reconnecting, no lastConnectedAt '
      'stamp', () async {
    await seedRelay('wss://r1');
    final reporter = RelayStatusReporter(isar);

    await reporter.report('wss://r1', ConnectionState.connecting);

    final row = await isar.relayModels.where().urlEqualTo('wss://r1').findFirst();
    expect(row!.status, RelayStatus.reconnecting);
    expect(row.lastConnectedAt, isNull);
  });

  test('disconnected maps to RelayStatus.disconnected, no lastConnectedAt '
      'stamp', () async {
    await seedRelay('wss://r1');
    final reporter = RelayStatusReporter(isar);

    await reporter.report('wss://r1', ConnectionState.disconnected);

    final row = await isar.relayModels.where().urlEqualTo('wss://r1').findFirst();
    expect(row!.status, RelayStatus.disconnected);
    expect(row.lastConnectedAt, isNull);
  });

  test('a prior lastConnectedAt is preserved across a disconnect report',
      () async {
    await seedRelay('wss://r1');
    final reporter = RelayStatusReporter(isar);
    await reporter.report('wss://r1', ConnectionState.connected);
    final firstStamp = (await isar.relayModels
            .where()
            .urlEqualTo('wss://r1')
            .findFirst())!
        .lastConnectedAt;

    await reporter.report('wss://r1', ConnectionState.disconnected);

    final row = await isar.relayModels.where().urlEqualTo('wss://r1').findFirst();
    expect(row!.lastConnectedAt, firstStamp);
  });
}
