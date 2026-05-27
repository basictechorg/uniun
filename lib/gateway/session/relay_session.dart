import 'dart:async';

import 'package:uniun/gateway/session/nostr_frame.dart';
import 'package:uniun/gateway/session/pending_ack_tracker.dart';
import 'package:uniun/gateway/transport/relay_connection.dart';

/// Wraps a [RelayConnection] and speaks NIP-01.
///
/// Owns: subscribe/unsubscribe via REQ/CLOSE, in-flight OK tracking, lifetime tag.
/// Emits: typed inbound events on [events], OKs on [okAcks], state on [states].
///
/// Knows nothing about Isar, kinds, or the queue.
enum SessionLifetime { persistent, ephemeral }

class RelaySession {
  final RelayConnection connection;
  final bool read;
  final bool write;
  final SessionLifetime lifetime;

  final PendingAckTracker pendingAck = PendingAckTracker();

  final _eventsController = StreamController<InboundEvent>.broadcast();
  final _okController = StreamController<InboundOk>.broadcast();
  final _eoseController = StreamController<InboundEose>.broadcast();

  StreamSubscription<String>? _frameSub;
  StreamSubscription<ConnectionState>? _stateSub;

  /// Whether the underlying transport is connected. Mirrors transport state.
  bool get isConnected => connection.isConnected;
  String get url => connection.url;
  Stream<InboundEvent> get events => _eventsController.stream;
  Stream<InboundOk> get okAcks => _okController.stream;
  Stream<InboundEose> get eoseEvents => _eoseController.stream;
  Stream<ConnectionState> get states => connection.states;

  RelaySession({
    required this.connection,
    required this.read,
    required this.write,
    this.lifetime = SessionLifetime.persistent,
  }) {
    _frameSub = connection.frames.listen(_onFrame);
    _stateSub = connection.states.listen((s) {
      if (s != ConnectionState.connected) pendingAck.clear();
    });
  }

  void connect() => connection.connect();

  Future<void> disconnect() async {
    await _frameSub?.cancel();
    await _stateSub?.cancel();
    await connection.disconnect();
    if (!_eventsController.isClosed) await _eventsController.close();
    if (!_okController.isClosed) await _okController.close();
    if (!_eoseController.isClosed) await _eoseController.close();
  }

  void subscribe(String subId, Map<String, dynamic> filter) {
    if (!read || !isConnected) return;
    connection.send(NostrFrame.req(subId, filter));
  }

  void unsubscribe(String subId) {
    if (!isConnected) return;
    connection.send(NostrFrame.close(subId));
  }

  /// Sends a raw, pre-encoded relay message (used for both serialized queue
  /// items and raw private-channel events).
  void sendRaw(String frame) {
    if (!isConnected) return;
    connection.send(frame);
  }

  void _onFrame(String raw) {
    final msg = decodeFrame(raw);
    if (msg == null) return;
    switch (msg) {
      case InboundEvent():
        if (read) _eventsController.add(msg);
      case InboundOk():
        _okController.add(msg);
      case InboundEose():
        _eoseController.add(msg);
      case InboundNotice():
      case InboundUnknown():
        break;
    }
  }
}
