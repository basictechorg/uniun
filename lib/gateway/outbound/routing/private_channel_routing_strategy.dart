import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/gateway/outbound/routing/routing_strategy.dart';

/// Kinds used by the Marmot private-channel protocol. Each carries an
/// `["h", groupId]` tag — now stored directly as [EventQueueModel.hTag], no
/// JSON parse needed.
const _privateChannelKinds = {9002, 9021, 9022, 9023, 9024, 9025};

/// Routes Marmot private-channel events to the group's stored relays
/// (falls back to all main relays when none are configured).
class PrivateChannelRoutingStrategy implements RoutingStrategy {
  @override
  bool matches(EventQueueModel event) =>
      _privateChannelKinds.contains(event.kind) ||
      event.kind == kPrivateChannelKind;

  @override
  Future<List<String>?> resolveTargets(
    EventQueueModel event,
    Isar isar,
  ) async {
    final groupId = event.hTag;
    if (groupId == null) return null;

    final channel = await isar.privateChannelModels
        .where()
        .groupIdEqualTo(groupId)
        .findFirst();
    if (channel != null && channel.relays.isNotEmpty) return channel.relays;
    return null;
  }
}
