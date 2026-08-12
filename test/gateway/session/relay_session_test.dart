import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/gateway/session/nostr_frame.dart';
import 'package:uniun/gateway/session/relay_session.dart';
import 'package:uniun/gateway/transport/relay_connection.dart';

class _FakeConnection extends RelayConnection {
  _FakeConnection({this.connected = true}) : super(url: 'wss://test.relay');

  bool connected;
  bool connectCalled = false;
  bool disconnectCalled = false;
  final List<String> sent = [];
  final _frames = StreamController<String>.broadcast();
  final _states = StreamController<ConnectionState>.broadcast();

  @override
  bool get isConnected => connected;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  Stream<ConnectionState> get states => _states.stream;

  @override
  void connect() => connectCalled = true;

  @override
  void send(String frame) {
    if (!connected) return;
    sent.add(frame);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
    await _frames.close();
    await _states.close();
  }

  void emitFrame(String raw) => _frames.add(raw);
  void emitState(ConnectionState s) => _states.add(s);
}

/// Covers: RelaySession's connect()/disconnect() delegation, subscribe()'s
/// read+connected gate and REQ encoding, unsubscribe()'s connected gate and
/// CLOSE encoding, sendRaw()'s connected gate, frame decoding dispatch
/// (EVENT gated on `read`, OK, EOSE always forwarded; NOTICE/malformed
/// silently dropped), the pendingAck-clear side effect on any non-connected
/// state transition, and disconnect() safely closing already-closed stream
/// controllers.
void main() {
  test('connect() delegates to the underlying connection', () {
    final conn = _FakeConnection();
    final session = RelaySession(connection: conn, read: true, write: true);
    session.connect();
    expect(conn.connectCalled, isTrue);
  });

  group('subscribe', () {
    test('sends a REQ frame when read + connected', () {
      final conn = _FakeConnection(connected: true);
      final session = RelaySession(connection: conn, read: true, write: true);
      session.subscribe('sub1', {'kinds': [1]});
      expect(conn.sent, hasLength(1));
      expect(conn.sent.single, NostrFrame.req('sub1', {'kinds': [1]}));
    });

    test('does nothing when read is false', () {
      final conn = _FakeConnection(connected: true);
      final session = RelaySession(connection: conn, read: false, write: true);
      session.subscribe('sub1', {'kinds': [1]});
      expect(conn.sent, isEmpty);
    });

    test('does nothing when not connected', () {
      final conn = _FakeConnection(connected: false);
      final session = RelaySession(connection: conn, read: true, write: true);
      session.subscribe('sub1', {'kinds': [1]});
      expect(conn.sent, isEmpty);
    });
  });

  group('unsubscribe', () {
    test('sends a CLOSE frame when connected', () {
      final conn = _FakeConnection(connected: true);
      final session = RelaySession(connection: conn, read: true, write: true);
      session.unsubscribe('sub1');
      expect(conn.sent.single, NostrFrame.close('sub1'));
    });

    test('does nothing when not connected', () {
      final conn = _FakeConnection(connected: false);
      final session = RelaySession(connection: conn, read: true, write: true);
      session.unsubscribe('sub1');
      expect(conn.sent, isEmpty);
    });
  });

  group('sendRaw', () {
    test('forwards the frame verbatim when connected', () {
      final conn = _FakeConnection(connected: true);
      final session = RelaySession(connection: conn, read: true, write: true);
      session.sendRaw('["EVENT", {}]');
      expect(conn.sent.single, '["EVENT", {}]');
    });

    test('does nothing when not connected', () {
      final conn = _FakeConnection(connected: false);
      final session = RelaySession(connection: conn, read: true, write: true);
      session.sendRaw('["EVENT", {}]');
      expect(conn.sent, isEmpty);
    });
  });

  group('frame dispatch', () {
    test('an EVENT frame is forwarded on `events` when read is true',
        () async {
      final conn = _FakeConnection();
      final session = RelaySession(connection: conn, read: true, write: true);
      final received = <InboundEvent>[];
      session.events.listen(received.add);

      conn.emitFrame(jsonEncode(['EVENT', 'sub1', {'id': 'e1'}]));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.subId, 'sub1');
    });

    test('an EVENT frame is swallowed (not forwarded) when read is false',
        () async {
      final conn = _FakeConnection();
      final session = RelaySession(connection: conn, read: false, write: true);
      final received = <InboundEvent>[];
      session.events.listen(received.add);

      conn.emitFrame(jsonEncode(['EVENT', 'sub1', {'id': 'e1'}]));
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
    });

    test('an OK frame is forwarded on okAcks regardless of read', () async {
      final conn = _FakeConnection();
      final session = RelaySession(connection: conn, read: false, write: true);
      final received = <InboundOk>[];
      session.okAcks.listen(received.add);

      conn.emitFrame(jsonEncode(['OK', 'e1', true]));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.eventId, 'e1');
    });

    test('an EOSE frame is forwarded on eoseEvents', () async {
      final conn = _FakeConnection();
      final session = RelaySession(connection: conn, read: true, write: true);
      final received = <InboundEose>[];
      session.eoseEvents.listen(received.add);

      conn.emitFrame(jsonEncode(['EOSE', 'sub1']));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
    });

    test('a NOTICE frame is dropped (no controller emits)', () async {
      final conn = _FakeConnection();
      final session = RelaySession(connection: conn, read: true, write: true);
      var eventsFired = false;
      var okFired = false;
      var eoseFired = false;
      session.events.listen((_) => eventsFired = true);
      session.okAcks.listen((_) => okFired = true);
      session.eoseEvents.listen((_) => eoseFired = true);

      conn.emitFrame(jsonEncode(['NOTICE', 'rate limited']));
      await Future<void>.delayed(Duration.zero);

      expect(eventsFired, isFalse);
      expect(okFired, isFalse);
      expect(eoseFired, isFalse);
    });

    test('an InboundUnknown frame (recognized JSON, unknown type) is '
        'silently dropped', () async {
      final conn = _FakeConnection();
      final session = RelaySession(connection: conn, read: true, write: true);
      var fired = false;
      session.events.listen((_) => fired = true);

      conn.emitFrame(jsonEncode(['CLOSED', 'sub1']));
      await Future<void>.delayed(Duration.zero);

      expect(fired, isFalse);
    });

    test('a malformed frame (decodeFrame returns null) is silently dropped',
        () async {
      final conn = _FakeConnection();
      final session = RelaySession(connection: conn, read: true, write: true);
      var fired = false;
      session.events.listen((_) => fired = true);

      conn.emitFrame('not-json');
      await Future<void>.delayed(Duration.zero);

      expect(fired, isFalse);
    });
  });

  test('a state transition away from connected clears the pending-ack slot',
      () async {
    final conn = _FakeConnection();
    final session = RelaySession(connection: conn, read: true, write: true);
    session.pendingAck.arm('evt-1', 1);
    expect(session.pendingAck.hasPending, isTrue);

    conn.emitState(ConnectionState.disconnected);
    await Future<void>.delayed(Duration.zero);

    expect(session.pendingAck.hasPending, isFalse);
  });

  test('a state transition to connected does NOT clear the pending-ack slot',
      () async {
    final conn = _FakeConnection();
    final session = RelaySession(connection: conn, read: true, write: true);
    session.pendingAck.arm('evt-1', 1);

    conn.emitState(ConnectionState.connected);
    await Future<void>.delayed(Duration.zero);

    expect(session.pendingAck.hasPending, isTrue);
  });

  test('disconnect() delegates and closes every controller without '
      'throwing on a second call', () async {
    final conn = _FakeConnection();
    final session = RelaySession(connection: conn, read: true, write: true);

    await session.disconnect();
    expect(conn.disconnectCalled, isTrue);

    // A second disconnect must not throw ("closed controller" errors).
    await expectLater(session.disconnect(), completes);
  });

  test('lifetime defaults to persistent', () {
    final conn = _FakeConnection();
    final session = RelaySession(connection: conn, read: true, write: true);
    expect(session.lifetime, SessionLifetime.persistent);
  });

  test('url and isConnected mirror the underlying connection', () {
    final conn = _FakeConnection(connected: true);
    final session = RelaySession(connection: conn, read: true, write: true);
    expect(session.url, 'wss://test.relay');
    expect(session.isConnected, isTrue);
  });

  test('states exposes the underlying connection\'s state stream', () async {
    final conn = _FakeConnection();
    final session = RelaySession(connection: conn, read: true, write: true);
    final received = <ConnectionState>[];
    session.states.listen(received.add);

    conn.emitState(ConnectionState.connected);
    await Future<void>.delayed(Duration.zero);

    expect(received, [ConnectionState.connected]);
  });
}
