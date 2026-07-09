import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/features/mesh/sync/bodies/group_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Kind 41 — NIP-28 group metadata update.
///
/// Only the original creator can update metadata, and only if the incoming
/// event is newer than the last known update.
///
/// When [activePubkey] + [activePrivkey] are provided the handler re-stamps
/// [GroupModel.signedNostrEvent] so the mesh sync scope advertises the latest
/// name / about / picture to the user's other devices.
class Kind41Handler implements KindHandler {
  Kind41Handler({this.activePubkey, this.activePrivkey});

  final String? activePubkey;
  final String? activePrivkey;

  @override
  Set<int> get kinds => const {41};

  @override
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    final groupId = EventParser.firstTagValue(event.toMap(), 'e');
    if (groupId == null) return;

    Map<String, dynamic> metadata;
    try {
      metadata = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    await isar.writeTxn(() async {
      final group = await isar.groupModels
          .where()
          .groupIdEqualTo(groupId)
          .findFirst();
      if (group == null) return;
      if (group.creatorPubKey != event.pubkey) return;
      if (event.createdAt <= group.updatedAt) return;

      group.name = metadata['name'] as String? ?? group.name;
      group.about = metadata['about'] as String? ?? group.about;
      group.picture = metadata['picture'] as String? ?? group.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        group.relays = relays.map((e) => e.toString()).toList();
      }

      group.updatedAt = event.createdAt;
      group.lastMetaEvent = event.id;

      // Re-stamp the mesh event so peers receive the latest metadata.
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
