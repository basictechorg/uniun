import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 40 — NIP-28 group creation.
///
/// The Nostr event id IS the group id forever. We only update existing
/// [GroupModel] rows (the group must have been joined locally first).
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
      final group = await isar.groupModels
          .where()
          .groupIdEqualTo(eventId)
          .findFirst();
      if (group == null) return;

      group.creatorPubKey = pubkey;
      group.createdAt = createdAt;
      group.name = metadata['name'] as String? ?? group.name;
      group.about = metadata['about'] as String? ?? group.about;
      group.picture = metadata['picture'] as String? ?? group.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        group.relays = relays.map((e) => e.toString()).toList();
      }

      await isar.groupModels.put(group);
    });
  }
}
