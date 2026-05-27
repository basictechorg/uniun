import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/gateway/outbound/routing/routing_strategy.dart';

/// Marmot private-channel events.
///
/// The full signed event JSON lives in [EventQueueModel.content] (so we can
/// preserve the `["h", groupId]` tag that the standard wire format strips).
/// Extract the `h` tag value, look up the [PrivateChannelModel] and use its
/// stored relays. Falls back to all main relays when missing or malformed.
class PrivateChannelRoutingStrategy implements RoutingStrategy {
  @override
  bool matches(EventQueueModel event) => event.isPrivateChannelEvent;

  @override
  Future<List<String>?> resolveTargets(
    EventQueueModel event,
    Isar isar,
  ) async {
    String? groupId;
    try {
      final decoded = jsonDecode(event.content) as Map<String, dynamic>;
      final tags = (decoded['tags'] as List<dynamic>? ?? []);
      groupId = tags
          .cast<List<dynamic>>()
          .where((t) => t.isNotEmpty && t[0] == 'h')
          .map((t) => t.length > 1 ? t[1] as String : null)
          .whereType<String>()
          .firstOrNull;
    } catch (_) {
      return null;
    }
    if (groupId == null) return null;

    final channel = await isar.privateChannelModels
        .where()
        .groupIdEqualTo(groupId)
        .findFirst();
    if (channel != null && channel.relays.isNotEmpty) return channel.relays;
    return null;
  }
}
