import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/gateway/transport/relay_connection.dart';

/// Writes the latest [RelayStatus] for a relay URL into [RelayModel].
///
/// Maps the transport-level [ConnectionState] (which knows nothing about Isar)
/// onto the persisted relay status enum the UI consumes.
class RelayStatusReporter {
  final Isar _isar;
  RelayStatusReporter(this._isar);

  Future<void> report(String url, ConnectionState state) async {
    final status = _mapToRelayStatus(state);
    await _isar.writeTxn(() async {
      final relay =
          await _isar.relayModels.where().urlEqualTo(url).findFirst();
      if (relay == null) return;
      relay.status = status;
      if (status == RelayStatus.connected) {
        relay.lastConnectedAt = DateTime.now();
      }
      await _isar.relayModels.put(relay);
    });
  }

  RelayStatus _mapToRelayStatus(ConnectionState s) {
    switch (s) {
      case ConnectionState.connected:
        return RelayStatus.connected;
      case ConnectionState.connecting:
        return RelayStatus.reconnecting;
      case ConnectionState.disconnected:
        return RelayStatus.disconnected;
    }
  }
}
