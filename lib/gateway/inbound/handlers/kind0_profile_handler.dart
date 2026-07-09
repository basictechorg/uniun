import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Kind 0 — user metadata (NIP-01 profile).
///
/// Upserts [ProfileModel] keyed by pubkey, refusing older versions, and
/// clears the matching [MissingProfilePubkeyModel] row if present.
class Kind0ProfileHandler implements KindHandler {
  @override
  Set<int> get kinds => const {0};

  @override
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    Map<String, dynamic> metadata;
    try {
      metadata = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final incomingUpdatedAt = EventParser.dateTimeFromSec(event.createdAt);

    try {
      await isar.writeTxn(() async {
        final existing = await isar.profileModels
            .where()
            .pubkeyEqualTo(event.pubkey)
            .findFirst();
        if (existing != null &&
            incomingUpdatedAt.isBefore(existing.updatedAt)) {
          return;
        }

        final model = existing ?? ProfileModel();
        model.pubkey = event.pubkey;
        model.name =
            metadata['display_name'] as String? ?? metadata['name'] as String?;
        model.username = metadata['name'] as String?;
        model.about = metadata['about'] as String?;
        model.avatarUrl = metadata['picture'] as String?;
        model.nip05 = metadata['nip05'] as String?;
        model.updatedAt = incomingUpdatedAt;
        model.lastSeenAt = existing?.lastSeenAt;
        model.rawEventJson = event.toCanonicalJson();

        await isar.profileModels.put(model);

        final missing = await isar.missingProfilePubkeyModels
            .where()
            .pubkeyEqualTo(event.pubkey)
            .findFirst();
        if (missing != null) {
          await isar.missingProfilePubkeyModels.delete(missing.id);
        }
      });
    } catch (_) {
      return;
    }
  }
}
