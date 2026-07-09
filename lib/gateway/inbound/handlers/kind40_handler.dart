import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/features/mesh/sync/bodies/group_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Kind 40 — NIP-28 group creation.
///
/// The Nostr event id IS the group id forever. We only update existing
/// [GroupModel] rows (the group must have been joined locally first).
///
/// When [activePubkey] + [activePrivkey] are provided the handler re-stamps
/// [GroupModel.signedNostrEvent] so the mesh sync scope advertises the updated
/// metadata (creator, name, relays) to the user's other devices.
class Kind40Handler implements KindHandler {
  Kind40Handler({this.activePubkey, this.activePrivkey});

  final String? activePubkey;
  final String? activePrivkey;

  @override
  Set<int> get kinds => const {40};

  @override
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    Map<String, dynamic> metadata;
    try {
      metadata = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    await isar.writeTxn(() async {
      final group = await isar.groupModels
          .where()
          .groupIdEqualTo(event.id)
          .findFirst();
      if (group == null) return;

      group.creatorPubKey = event.pubkey;
      group.createdAt = event.createdAt;
      group.name = metadata['name'] as String? ?? group.name;
      group.about = metadata['about'] as String? ?? group.about;
      group.picture = metadata['picture'] as String? ?? group.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        group.relays = relays.map((e) => e.toString()).toList();
      }

      // Re-stamp the mesh event so peers receive the authoritative metadata.
      // Skip when no identity is active (the signer migration pass will
      // backfill on next launch).
      final priv = activePrivkey;
      final pub = activePubkey;
      if (priv != null && pub != null && group.removedAt == null) {
        group.signedNostrEvent = await MeshEventCodec(
          privkeyHex: priv,
          pubkeyHex: pub,
        ).signRecord(
          kind: MeshEventKinds.group,
          dTag: group.groupId,
          content: GroupBody.forActive(group),
        );
      }

      await isar.groupModels.put(group);
    });
  }
}
