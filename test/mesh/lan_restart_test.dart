import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/mesh/link/mesh_link.dart';
import 'package:uniun/features/mesh/transport/lan/lan_connector.dart';

/// After a Wi-Fi change the engine must rebind the LAN server on the new network
/// interface WITHOUT an app restart. [LanConnector.restartServer] rebinds the
/// inbound server and — crucially — keeps the [LanConnector.links] stream alive,
/// so the negotiator wiring the engine set up above the seam is untouched (a naive
/// stop()+start() would close that stream).
void main() {
  test('restartServer rebinds and keeps accepting with links stream still open',
      () async {
    final connector = LanConnector();
    final firstPort = await connector.start();
    expect(firstPort, greaterThan(0));

    // An inbound connection on the first port surfaces as a MeshLink.
    final firstLink = Completer<MeshLink>();
    final sub1 = connector.links.listen((l) {
      if (!firstLink.isCompleted) firstLink.complete(l);
    });
    final c1 = await Socket.connect(InternetAddress.loopbackIPv4, firstPort);
    await firstLink.future.timeout(const Duration(seconds: 5));

    // Rebind (simulating recovery after a network change).
    final secondPort = await connector.restartServer();
    expect(secondPort, greaterThan(0));

    // The links stream is STILL OPEN and the rebound server accepts again.
    final secondLink = Completer<MeshLink>();
    final sub2 = connector.links.listen((l) {
      if (!secondLink.isCompleted) secondLink.complete(l);
    });
    final c2 = await Socket.connect(InternetAddress.loopbackIPv4, secondPort);
    final link2 = await secondLink.future.timeout(const Duration(seconds: 5));
    expect(link2.isConnected, isTrue);

    await sub1.cancel();
    await sub2.cancel();
    c1.destroy();
    c2.destroy();
    await connector.stop();
  });
}
