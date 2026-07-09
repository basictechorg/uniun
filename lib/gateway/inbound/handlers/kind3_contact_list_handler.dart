import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Kind 3 — NIP-02 contact list.
///
/// Only events authored by the active user are applied (others' contact lists
/// are not stored locally — they would be useless without a "followers" UI and
/// we'd just be hoarding everyone's social graph). Last-write-wins by
/// `created_at`: an older Kind 3 is ignored, a newer one fully replaces the
/// local [FollowedUserModel] rows by diff (preserves `followedAt` for rows
/// that survive).
class Kind3ContactListHandler implements KindHandler {
  Kind3ContactListHandler({required this.activePubkey});

  /// Active user's hex pubkey. Null = no logged-in user — handler is a no-op.
  final String? activePubkey;

  @override
  Set<int> get kinds => const {3};

  @override
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    if (activePubkey == null) return;
    if (event.pubkey != activePubkey) return;

    final incomingCreatedAt = EventParser.dateTimeFromSec(event.createdAt);

    final incoming = <String, ({String? relay, String? petname})>{};
    for (final raw in event.tags) {
      if (raw.isEmpty) continue;
      if (raw[0] != 'p' || raw.length < 2) continue;
      final hex = raw[1];
      if (hex.isEmpty) continue;
      final relay = raw.length >= 3 && raw[2].isNotEmpty ? raw[2] : null;
      final petname = raw.length >= 4 && raw[3].isNotEmpty ? raw[3] : null;
      incoming[hex] = (relay: relay, petname: petname);
    }

    try {
      await isar.writeTxn(() async {
        final existing = await isar.followedUserModels.where().findAll();

        // Reject if any existing row was last updated by a newer Kind 3.
        // (Picks the max across rows so we ignore the whole event atomically.)
        DateTime? latest;
        for (final r in existing) {
          final t = r.lastKind3CreatedAt;
          if (t != null && (latest == null || t.isAfter(latest))) latest = t;
        }
        if (latest != null && !incomingCreatedAt.isAfter(latest)) return;

        final existingByPubkey = {for (final r in existing) r.pubkeyHex: r};

        for (final row in existing) {
          if (!incoming.containsKey(row.pubkeyHex)) {
            row.lastKind3CreatedAt = incomingCreatedAt;
            row.removedAt = incomingCreatedAt;
            await isar.followedUserModels.put(row);
          }
        }

        for (final entry in incoming.entries) {
          final hex = entry.key;
          final meta = entry.value;
          final prev = existingByPubkey[hex];
          final row = prev ?? FollowedUserModel();
          row.pubkeyHex = hex;
          row.relayHint = meta.relay;
          row.petname = meta.petname;
          row.followedAt = prev?.followedAt ?? incomingCreatedAt;
          row.lastKind3CreatedAt = incomingCreatedAt;
          row.removedAt = null;
          await isar.followedUserModels.put(row);
        }
      });
    } catch (_) {
      return;
    }
  }
}
