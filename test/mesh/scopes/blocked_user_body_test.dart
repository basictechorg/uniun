// Round-trip tests for [BlockedUserBody] — plaintext body shape for Kind-30502.

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/models/blocked_user_model.dart';
import 'package:uniun/features/mesh/sync/bodies/blocked_user_body.dart';

void main() {
  test('forActive → applyBody preserves every column', () {
    final src = BlockedUserModel()
      ..pubkeyHex = 'pk-1'
      ..blockedAt = DateTime.fromMillisecondsSinceEpoch(1720000100000);

    final body = BlockedUserBody.forActive(src);
    expect(body['state'], 'active');

    final round = BlockedUserBody.applyBody(body, pubkeyHex: 'pk-1');
    expect(round.pubkeyHex, 'pk-1');
    expect(round.blockedAt.millisecondsSinceEpoch, 1720000100000);
  });

  test('forRemoved emits state=removed', () {
    final src = BlockedUserModel()
      ..pubkeyHex = 'pk-r'
      ..blockedAt = DateTime.fromMillisecondsSinceEpoch(1720000200000);

    final body = BlockedUserBody.forRemoved(src);
    expect(body['state'], 'removed');

    final round = BlockedUserBody.applyBody(body, pubkeyHex: 'pk-r');
    expect(round.blockedAt.millisecondsSinceEpoch, 1720000200000);
  });

  test('applyBody updates an existing row in place', () {
    final existing = BlockedUserModel()
      ..pubkeyHex = 'pk-x'
      ..blockedAt = DateTime.fromMillisecondsSinceEpoch(0);

    final src = BlockedUserModel()
      ..pubkeyHex = 'pk-x'
      ..blockedAt = DateTime.fromMillisecondsSinceEpoch(1720000300000);

    final round = BlockedUserBody.applyBody(
      BlockedUserBody.forActive(src),
      pubkeyHex: 'pk-x',
      existing: existing,
    );
    expect(identical(round, existing), isTrue);
    expect(round.blockedAt.millisecondsSinceEpoch, 1720000300000);
  });

  test('applyBody tolerates missing blockedAt', () {
    final round = BlockedUserBody.applyBody(
      <String, dynamic>{'state': 'active'},
      pubkeyHex: 'x',
    );
    expect(round.blockedAt.millisecondsSinceEpoch, 0);
  });
}
