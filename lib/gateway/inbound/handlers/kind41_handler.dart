import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 41 — NIP-28 group metadata update.
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

    final groupId = EventParser.firstTagValue(event, 'e');
    if (groupId == null) return;

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
          .groupIdEqualTo(groupId)
          .findFirst();
      if (group == null) return;
      if (group.creatorPubKey != pubkey) return;
      if (createdAt <= group.updatedAt) return;

      group.name = metadata['name'] as String? ?? group.name;
      group.about = metadata['about'] as String? ?? group.about;
      group.picture = metadata['picture'] as String? ?? group.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        group.relays = relays.map((e) => e.toString()).toList();
      }

      group.updatedAt = createdAt;
      group.lastMetaEvent = eventId;

      await isar.groupModels.put(group);
    });
  }
}
