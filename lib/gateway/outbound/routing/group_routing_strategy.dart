import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/gateway/outbound/routing/routing_strategy.dart';

/// NIP-28 group events (kinds 40–44).
///
/// - Kind 40: group id == event id, so use [EventQueueModel.eventId].
/// - Kind 41–44: group id is the root e-tag → [EventQueueModel.rootEventId].
///
/// Falls back to "all main relays" (returns null) when no [GroupModel]
/// exists locally or it carries no relay list.
class GroupRoutingStrategy implements RoutingStrategy {
  @override
  bool matches(EventQueueModel event) => event.kind >= 40 && event.kind <= 44;

  @override
  Future<List<String>?> resolveTargets(
    EventQueueModel event,
    Isar isar,
  ) async {
    final groupId =
        event.kind == 40 ? event.eventId : event.rootEventId;
    if (groupId == null) return null;

    final group = await isar.groupModels
        .where()
        .groupIdEqualTo(groupId)
        .findFirst();
    if (group != null && group.relays.isNotEmpty) return group.relays;
    return null;
  }
}
