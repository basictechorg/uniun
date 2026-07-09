// Round-trip tests for [DmConversationBody] — plaintext body shape for
// Kind-30503. Pure Dart, no Isar. `lastReadEventId` is intentionally NOT
// carried (per-device unread state — plan §5).

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/features/mesh/sync/bodies/dm_conversation_body.dart';

void main() {
  test('forActive → applyBody preserves counterparty + relays', () {
    final src = DmConversationModel()
      ..otherPubkey = 'pk-1'
      ..relays = const ['wss://relay.example', 'wss://relay.other'];

    final body = DmConversationBody.forActive(src);
    expect(body['state'], 'active');

    final round =
        DmConversationBody.applyBody(body, otherPubkey: 'pk-1');
    expect(round.otherPubkey, 'pk-1');
    expect(round.relays, ['wss://relay.example', 'wss://relay.other']);
  });

  test('forRemoved emits state=removed', () {
    final src = DmConversationModel()
      ..otherPubkey = 'pk-r'
      ..relays = const ['wss://r'];
    final body = DmConversationBody.forRemoved(src);
    expect(body['state'], 'removed');

    final round =
        DmConversationBody.applyBody(body, otherPubkey: 'pk-r');
    expect(round.relays, ['wss://r']);
  });

  test('applyBody updates an existing row in place', () {
    final existing = DmConversationModel()
      ..otherPubkey = 'pk-x'
      ..relays = const ['wss://old'];

    final src = DmConversationModel()
      ..otherPubkey = 'pk-x'
      ..relays = const ['wss://new'];

    final round = DmConversationBody.applyBody(
      DmConversationBody.forActive(src),
      otherPubkey: 'pk-x',
      existing: existing,
    );
    expect(identical(round, existing), isTrue);
    expect(round.relays, ['wss://new']);
  });

  test('applyBody defaults relays to empty when missing / malformed', () {
    final round = DmConversationBody.applyBody(
      <String, dynamic>{'state': 'active'},
      otherPubkey: 'x',
    );
    expect(round.relays, isEmpty);

    final round2 = DmConversationBody.applyBody(
      <String, dynamic>{'state': 'active', 'relays': 'not-a-list'},
      otherPubkey: 'x',
    );
    expect(round2.relays, isEmpty);
  });

  test('body does NOT carry lastReadEventId', () {
    // Per plan §5, cross-device read state is out of scope. The
    // `DmConversationModel` deliberately has no `lastReadEventId` field —
    // read state lives on the per-device `DMReadStateModel`. Guard against
    // a future refactor that adds one to the wire body.
    final src = DmConversationModel()
      ..otherPubkey = 'pk-1'
      ..relays = const [];

    final body = DmConversationBody.forActive(src);
    expect(body.containsKey('lastReadEventId'), isFalse);
  });
}
