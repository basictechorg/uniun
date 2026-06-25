import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/data/models/report_model.dart';

import '../../_helpers/isar_test_harness.dart';

/// Storage-level guarantees for ReportModel:
///   - the unique-replace index on `eventId` makes inserts idempotent
///   - the `targetEventId` index supports targeted lookups
///   - `toDomain()` rehydrates the [ReportType] enum from its `.name`
void main() {
  late Isar isar;
  setUp(() async => isar = await openTestIsar());
  tearDown(() async => isar.close(deleteFromDisk: true));

  ReportModel seed({
    required String eventId,
    String? targetEventId,
    String targetPubkey = 'pk',
    ReportType type = ReportType.spam,
  }) =>
      ReportModel()
        ..eventId = eventId
        ..reportType = type.name
        ..targetEventId = targetEventId
        ..targetPubkey = targetPubkey
        ..content = ''
        ..created = DateTime(2026, 6, 1);

  test('unique-replace index on eventId — re-put with same id keeps one row',
      () async {
    await isar.writeTxn(() async {
      await isar.reportModels.put(seed(eventId: 'e1'));
      await isar.reportModels.put(seed(eventId: 'e1', type: ReportType.other));
    });
    final all = await isar.reportModels.where().findAll();
    expect(all, hasLength(1));
    expect(all.first.reportType, ReportType.other.name);
  });

  test('lookup by targetEventId returns the existing row', () async {
    await isar.writeTxn(() async {
      await isar.reportModels
          .put(seed(eventId: 'e1', targetEventId: 'noteA'));
      await isar.reportModels
          .put(seed(eventId: 'e2', targetEventId: 'noteB'));
    });
    final found = await isar.reportModels
        .where()
        .targetEventIdEqualTo('noteA')
        .findFirst();
    expect(found, isNotNull);
    expect(found!.eventId, 'e1');
  });

  test('lookup by missing targetEventId returns null', () async {
    final found = await isar.reportModels
        .where()
        .targetEventIdEqualTo('nope')
        .findFirst();
    expect(found, isNull);
  });

  test('toDomain rehydrates ReportType from its name', () async {
    final row = seed(eventId: 'e1', type: ReportType.impersonation);
    expect(row.toDomain().type, ReportType.impersonation);
  });

  test('toDomain falls back to ReportType.other for an unknown name', () {
    // Defensive against forward-compatibility: future relays could ship report
    // types we don't know yet. ReportType.other is the documented bucket.
    final row = ReportModel()
      ..eventId = 'e1'
      ..reportType = 'totally_new_category'
      ..targetEventId = null
      ..targetPubkey = 'pk'
      ..content = ''
      ..created = DateTime(2026, 6, 1);
    expect(row.toDomain().type, ReportType.other);
  });
}
