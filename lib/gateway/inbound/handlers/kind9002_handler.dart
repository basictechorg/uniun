import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Kind 9002 — Marmot private group metadata.
///
/// Identifies the group by event id (== groupId in this protocol) and
/// updates name/description/admin/relays on an existing local row.
class Kind9002Handler implements KindHandler {
  @override
  Set<int> get kinds => const {9002};

  @override
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    Map<String, dynamic> metadata;
    try {
      metadata = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    await isar.writeTxn(() async {
      final group = await isar.privateGroupModels
          .where()
          .groupIdEqualTo(event.id)
          .findFirst();
      if (group == null) return;

      group.name = metadata['name'] as String? ?? group.name;
      group.description = metadata['about'] as String? ?? group.description;
      group.adminPubkey = event.pubkey;

      final relays = metadata['relays'];
      if (relays is List && relays.isNotEmpty) {
        group.relays = relays.map((e) => e.toString()).toList();
      }

      await isar.privateGroupModels.put(group);
    });
  }
}
