import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/gateway/outbound/routing/routing_strategy.dart';

/// NIP-28 channel events (kinds 40–44).
///
/// - Kind 40: channel id == event id, so use [EventQueueModel.eventId].
/// - Kind 41–44: channel id is the root e-tag → [EventQueueModel.rootEventId].
///
/// Falls back to "all main relays" (returns null) when no [ChannelModel]
/// exists locally or it carries no relay list.
class ChannelRoutingStrategy implements RoutingStrategy {
  @override
  bool matches(EventQueueModel event) => event.kind >= 40 && event.kind <= 44;

  @override
  Future<List<String>?> resolveTargets(
    EventQueueModel event,
    Isar isar,
  ) async {
    final channelId =
        event.kind == 40 ? event.eventId : event.rootEventId;
    if (channelId == null) return null;

    final channel = await isar.channelModels
        .where()
        .channelIdEqualTo(channelId)
        .findFirst();
    if (channel != null && channel.relays.isNotEmpty) return channel.relays;
    return null;
  }
}
