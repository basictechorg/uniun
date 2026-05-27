import 'dart:async';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionState { connecting, connected, disconnected }

/// One WebSocket to one relay URL. Knows nothing about Nostr.
///
/// Owns: TCP/WebSocket readiness, exponential-backoff reconnect, raw frame IO.
/// Emits: incoming text frames on [frames], state transitions on [states].
class RelayConnection {
  final String url;

  final _framesController = StreamController<String>.broadcast();
  final _statesController = StreamController<ConnectionState>.broadcast();

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;

  int _reconnectAttempt = 0;
  ConnectionState _state = ConnectionState.disconnected;
  bool _disposed = false;

  RelayConnection({required this.url});

  Stream<String> get frames => _framesController.stream;
  Stream<ConnectionState> get states => _statesController.stream;
  ConnectionState get state => _state;
  bool get isConnected => _state == ConnectionState.connected;

  void connect() {
    if (_disposed) return;
    _setState(ConnectionState.connecting);
    try {
      _socket = WebSocketChannel.connect(Uri.parse(url));
      _socket!.ready
          .then((_) {
            if (_disposed) return;
            _socketSub = _socket!.stream.listen(
              (raw) {
                if (raw is String) _framesController.add(raw);
              },
              onError: (_) => _scheduleReconnect(),
              onDone: _scheduleReconnect,
              cancelOnError: true,
            );
            _reconnectAttempt = 0;
            _setState(ConnectionState.connected);
          })
          .catchError((_) {
            _scheduleReconnect();
          });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void send(String frame) {
    if (!isConnected || _socket == null) return;
    _socket!.sink.add(frame);
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _socketSub?.cancel();
    await _socket?.sink.close();
    _setState(ConnectionState.disconnected);
    await _framesController.close();
    await _statesController.close();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _setState(ConnectionState.disconnected);
    _socketSub?.cancel();
    _socket?.sink.close();

    final delaySec = min(pow(2, _reconnectAttempt).toInt(), 60);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySec), connect);
  }

  void _setState(ConnectionState s) {
    if (_state == s) return;
    _state = s;
    if (!_statesController.isClosed) _statesController.add(s);
  }
}
