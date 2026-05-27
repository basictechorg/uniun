import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/encrypted_dm_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 1059 — NIP-17 gift-wrapped direct message.
///
/// We only store the encrypted envelope here. Decryption happens in
/// [Nip17EncryptionService] on the main isolate.
class Kind1059DmHandler implements KindHandler {
  @override
  Set<int> get kinds => const {1059};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final eventId = event['id'] as String?;
    if (eventId == null) {
      return;
    }

    final pTagRef = EventParser.firstTagValue(event, 'p');
    if (pTagRef == null) {
      return;
    }

    final model = EncryptedDmModel(
      eventId: eventId,
      sig: event['sig'] as String? ?? '',
      authorPubkey: event['pubkey'] as String? ?? '',
      pTagRef: pTagRef,
      content: event['content'] as String? ?? '',
      kind: event['kind'] as int? ?? 1059,
      created: EventParser.dateTimeFromSec(event['created_at'] as int? ?? 0),
    );

    try {
      await isar.writeTxn(() async {
        final existing = await isar.encryptedDmModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await isar.encryptedDmModels.put(model);
      });
    } catch (_) {
      return;
    }
  }
}
