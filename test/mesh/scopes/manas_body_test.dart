// Body-level roundtrip for Kind 30510 (Manas definition, plan §5).

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/features/mesh/sync/bodies/manas_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';

void main() {
  ManasModel makeRow() => ManasModel()
    ..manasId = 'manas-1'
    ..name = 'Research'
    ..description = 'papers I want to remember'
    ..iconName = 'science'
    ..createdAt = DateTime.fromMillisecondsSinceEpoch(1720000000000)
    ..updatedAt = DateTime.fromMillisecondsSinceEpoch(1720001000000);

  test('forActive encodes every field', () {
    final body = ManasBody.forActive(makeRow());
    expect(body['state'], MeshRecordState.active.wire);
    expect(body['name'], 'Research');
    expect(body['description'], 'papers I want to remember');
    expect(body['iconName'], 'science');
    expect(body['createdAt'], 1720000000000);
    expect(body['updatedAt'], 1720001000000);
  });

  test('forRemoved flips state but keeps identifiers', () {
    final body = ManasBody.forRemoved(makeRow());
    expect(body['state'], MeshRecordState.removed.wire);
    expect(body['name'], 'Research');
    expect(body['createdAt'], 1720000000000);
  });

  test('applyBody rehydrates onto a new row', () {
    final body = ManasBody.forActive(makeRow());
    final row = ManasBody.applyBody(body, manasId: 'manas-1');
    expect(row.manasId, 'manas-1');
    expect(row.name, 'Research');
    expect(row.description, 'papers I want to remember');
    expect(row.iconName, 'science');
    expect(row.createdAt.millisecondsSinceEpoch, 1720000000000);
    expect(row.updatedAt.millisecondsSinceEpoch, 1720001000000);
  });

  test('applyBody merges onto an existing row (preserving Isar id)', () {
    final existing = makeRow()..id = 42;
    final body = ManasBody.forActive(
      makeRow()
        ..name = 'Renamed'
        ..updatedAt = DateTime.fromMillisecondsSinceEpoch(1720002000000),
    );
    final row =
        ManasBody.applyBody(body, manasId: 'manas-1', existing: existing);
    expect(row.id, 42);
    expect(row.name, 'Renamed');
    expect(row.updatedAt.millisecondsSinceEpoch, 1720002000000);
  });

  test('applyBody tolerates a missing name (falls back to empty)', () {
    final row = ManasBody.applyBody(
      <String, dynamic>{
        'state': 'active',
        'createdAt': 1720000000000,
        'updatedAt': 1720000000000,
      },
      manasId: 'manas-x',
    );
    expect(row.name, '');
    expect(row.description, isNull);
    expect(row.iconName, isNull);
  });
}
