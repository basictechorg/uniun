import 'dart:convert';
import 'package:uniun/data/models/event_queue_model.dart';

/// Kinds used by the Marmot private channel protocol.
const _privateChannelKinds = {9002, 9021, 9022, 9023, 9024, 9025};

extension EventQueuePrivateChannelExt on EventQueueModel {
  /// Returns true when this queue entry carries a Marmot private-channel event.
  ///
  /// For these events the full signed Nostr event JSON is stored in [content]
  /// (rather than just the event's content string) so we can preserve the
  /// `["h", groupId]` tag that [toSerializedRelayMessage] cannot produce.
  bool get isPrivateChannelEvent => _privateChannelKinds.contains(kind);

  /// Converts this entry to the relay wire format `["EVENT", {signed-event}]`.
  ///
  /// Requires that [content] holds the full signed event JSON, as produced by
  /// `jsonEncode(event.toJson())` from nostr_core_dart.
  String toRawRelayMessage() {
    return jsonEncode(['EVENT', jsonDecode(content)]);
  }
}
