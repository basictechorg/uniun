import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/encrypted_message_model.dart';
import 'package:uniun/data/models/private_group_join_request_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kinds 9021–9025 — Marmot private group envelopes.
///
/// - 9021: a join request — keep the key package payload for the group admin.
/// - 9022–9025: encrypted message envelopes — stored verbatim for the main
///   isolate to decrypt.
class Kind9021To9025Handler implements KindHandler {
  /// The active user's public key (hex). Only the group admin needs to retain
  /// inbound join requests, so this is used to gate storage of kind 9021.
  final String? activePubkey;

  Kind9021To9025Handler({this.activePubkey});

  @override
  Set<int> get kinds => const {9021, 9022, 9023, 9024, 9025};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final kind = event['kind'] as int?;
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final content = event['content'] as String?;
    final createdAtSec = event['created_at'] as int?;
    if (kind == null ||
        eventId == null ||
        pubkey == null ||
        content == null ||
        createdAtSec == null) {
      return;
    }

    final groupId = EventParser.firstTagValue(event, 'h');
    if (groupId == null) return;

    final timestamp = EventParser.dateTimeFromSec(createdAtSec);

    if (kind == 9021) {
      // Only the group admin can approve join requests, so only the admin
      // needs to store them. Members (and the requester themselves) also receive
      // the relayed 9021 event but must not persist it.
      final group = await isar.privateGroupModels
          .where()
          .groupIdEqualTo(groupId)
          .findFirst();
      if (group == null ||
          activePubkey == null ||
          group.adminPubkey != activePubkey) {
        return;
      }

      final model = PrivateGroupJoinRequestModel()
        ..eventId = eventId
        ..groupId = groupId
        ..senderPubkey = pubkey
        ..keyPackageB64 = content
        ..timestamp = timestamp;
      try {
        await isar.writeTxn(() async {
          final existing = await isar.privateGroupJoinRequestModels
              .where()
              .eventIdEqualTo(eventId)
              .findFirst();
          if (existing != null) return;
          await isar.privateGroupJoinRequestModels.put(model);
        });
      } catch (_) {}
      return;
    }

    final model = EncryptedMessageModel()
      ..eventId = eventId
      ..groupId = groupId
      ..senderPubkey = pubkey
      ..kind = kind
      ..encryptedPayload = content
      ..timestamp = timestamp;
    try {
      await isar.writeTxn(() async {
        final existing = await isar.encryptedMessageModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await isar.encryptedMessageModels.put(model);
      });
    } catch (_) {}
  }
}
