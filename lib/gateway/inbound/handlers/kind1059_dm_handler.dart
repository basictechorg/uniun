import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/encrypted_dm_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Kind 1059 — NIP-17 gift-wrapped direct message.
///
/// We only store the encrypted envelope here. Decryption happens in
/// [Nip17EncryptionService] on the main isolate.
class Kind1059DmHandler implements KindHandler {
  @override
  Set<int> get kinds => const {1059};

  @override
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    final pTagRef = EventParser.firstTagValue(event.toMap(), 'p');
    if (pTagRef == null) {
      return;
    }

    final model = EncryptedDmModel(
      eventId: event.id,
      sig: event.sig,
      authorPubkey: event.pubkey,
      pTagRef: pTagRef,
      content: event.content,
      kind: event.kind,
      created: EventParser.dateTimeFromSec(event.createdAt),
    );

    try {
      await isar.writeTxn(() async {
        final existing = await isar.encryptedDmModels
            .where()
            .eventIdEqualTo(event.id)
            .findFirst();
        if (existing != null) return;
        await isar.encryptedDmModels.put(model);
      });
    } catch (_) {
      return;
    }
  }
}
