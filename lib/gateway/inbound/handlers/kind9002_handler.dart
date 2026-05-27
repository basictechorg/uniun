import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 9002 — Marmot private channel metadata.
///
/// Identifies the channel by event id (== groupId in this protocol) and
/// updates name/description/admin/relays on an existing local row.
class Kind9002Handler implements KindHandler {
  @override
  Set<int> get kinds => const {9002};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    if (eventId == null || pubkey == null) return;

    Map<String, dynamic> metadata;
    try {
      metadata =
          jsonDecode(event['content'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    await isar.writeTxn(() async {
      final channel = await isar.privateChannelModels
          .where()
          .groupIdEqualTo(eventId)
          .findFirst();
      if (channel == null) return;

      channel.name = metadata['name'] as String? ?? channel.name;
      channel.description =
          metadata['about'] as String? ?? channel.description;
      channel.adminPubkey = pubkey;

      final relays = metadata['relays'];
      if (relays is List && relays.isNotEmpty) {
        channel.relays = relays.map((e) => e.toString()).toList();
      }

      await isar.privateChannelModels.put(channel);
    });
  }
}
