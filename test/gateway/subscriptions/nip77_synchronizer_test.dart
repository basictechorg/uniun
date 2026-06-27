import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nip77/nip77.dart';
import 'package:uniun/gateway/session/relay_session.dart';
import 'package:uniun/gateway/subscriptions/nip77_synchronizer.dart';
import 'package:uniun/gateway/transport/relay_connection.dart';

/// A [RelayConnection] that reports itself permanently connected and records
/// every frame instead of opening a socket.
class _CapturingConnection extends RelayConnection {
  _CapturingConnection() : super(url: 'wss://test.relay');

  final List<String> sent = [];

  @override
  bool get isConnected => true;

  @override
  void send(String frame) => sent.add(frame);
}

void main() {
  test(
      'supportsNip77=false rides a plain REQ even with a connected shared '
      'client — no negentropy sync, no since=now tail', () async {
    // Regression for the profile-backfill bug: SubscriptionManager.openAll
    // shares one connected Nip77Client across every provider, including the
    // kind-0 profiles provider (supportsNip77=false). Without the early return
    // that provider would run syncEvents on the kind-0 filter and then emit a
    // since=now live-tail, silently dropping all historical profiles.
    final conn = _CapturingConnection();
    final session = RelaySession(connection: conn, read: true, write: false);
    var localIndexCalled = false;
    final filter = <String, dynamic>{
      'kinds': [0],
      'authors': ['pkA', 'pkB'],
    };

    await Nip77Synchronizer().syncOrFallback(
      session: session,
      subId: 'profiles',
      filter: filter,
      localIndex: () async {
        localIndexCalled = true;
        return <String, int>{};
      },
      sharedClient: Nip77Client(relayUrl: 'wss://test.relay'),
      sharedClientConnected: true,
      supportsNip77: false,
    );

    // localIndex() is only invoked inside the NIP-77 sync branch, so its NOT
    // being called proves the early return fired before any sync attempt.
    expect(localIndexCalled, isFalse);

    // Exactly one frame: a plain REQ carrying the full filter, with no
    // since key that would skip historical profiles.
    expect(conn.sent, hasLength(1));
    final decoded = jsonDecode(conn.sent.single) as List;
    expect(decoded[0], 'REQ');
    expect(decoded[1], 'profiles');
    expect((decoded[2] as Map).containsKey('since'), isFalse);
    expect((decoded[2] as Map)['kinds'], [0]);
  });
}
