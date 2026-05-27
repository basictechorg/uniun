import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 40 — NIP-28 channel creation.
///
/// The Nostr event id IS the channel id forever. We only update existing
/// [ChannelModel] rows (the channel must have been joined locally first).
class Kind40Handler implements KindHandler {
  @override
  Set<int> get kinds => const {40};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final createdAt = event['created_at'] as int?;
    if (eventId == null || pubkey == null || createdAt == null) return;

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
          .channelIdEqualTo(eventId)
          .findFirst();
      if (channel == null) return;

      channel.creatorPubKey = pubkey;
      channel.createdAt = createdAt;
      channel.name = metadata['name'] as String? ?? channel.name;
      channel.about = metadata['about'] as String? ?? channel.about;
      channel.picture = metadata['picture'] as String? ?? channel.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        channel.relays = relays.map((e) => e.toString()).toList();
      }

      await isar.channelModels.put(channel);
    });
  }
}
