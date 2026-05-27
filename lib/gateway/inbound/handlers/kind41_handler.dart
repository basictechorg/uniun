import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 41 — NIP-28 channel metadata update.
///
/// Only the original creator can update metadata, and only if the incoming
/// event is newer than the last known update.
class Kind41Handler implements KindHandler {
  @override
  Set<int> get kinds => const {41};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final createdAt = event['created_at'] as int?;
    if (eventId == null || pubkey == null || createdAt == null) return;

    final channelId = EventParser.firstTagValue(event, 'e');
    if (channelId == null) return;

    Map<String, dynamic> metadata;
    try {
      metadata =
          jsonDecode(event['content'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    await isar.writeTxn(() async {
      final channel = await isar.channelModels
          .where()
          .channelIdEqualTo(channelId)
          .findFirst();
      if (channel == null) return;
      if (channel.creatorPubKey != pubkey) return;
      if (createdAt <= channel.updatedAt) return;

      channel.name = metadata['name'] as String? ?? channel.name;
      channel.about = metadata['about'] as String? ?? channel.about;
      channel.picture = metadata['picture'] as String? ?? channel.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        channel.relays = relays.map((e) => e.toString()).toList();
      }

      channel.updatedAt = createdAt;
      channel.lastMetaEvent = eventId;

      await isar.channelModels.put(channel);
    });
  }
}
