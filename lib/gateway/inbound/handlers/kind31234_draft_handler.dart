import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:nip44/nip44.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/draft_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// NIP-37 — encrypted draft wrap (Kind 31234).
///
/// Only events authored by the active user are applied. Last-write-wins by
/// `created_at` against [DraftModel.lastSyncedCreatedAt]: an older wrap is
/// ignored, a newer one replaces the local row. Empty `content` is the
/// NIP-37 deletion signal — local row is deleted.
class Kind31234DraftHandler implements KindHandler {
  Kind31234DraftHandler({
    required this.activePubkey,
    required this.activePrivkey,
  });

  /// Active user's hex pubkey. Null → no logged-in user, handler is a no-op.
  final String? activePubkey;

  /// Active user's hex privkey. Null → cannot decrypt, handler is a no-op.
  final String? activePrivkey;

  @override
  Set<int> get kinds => const {kDraftWrapKind};

  @override
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    if (activePubkey == null || activePrivkey == null) {
      return;
    }
    if (event.pubkey != activePubkey) return;

    final draftId = _firstTagValue(event.tags, 'd');
    if (draftId == null) return;

    final incomingCreatedAt = EventParser.dateTimeFromSec(event.createdAt);

    final existing = await isar.draftModels
        .filter()
        .draftIdEqualTo(draftId)
        .findFirst();
    final lastSeen = existing?.lastSyncedCreatedAt;
    if (lastSeen != null && !incomingCreatedAt.isAfter(lastSeen)) return;

    // Empty content → NIP-37 deletion signal.
    if (event.content.isEmpty) {
      if (existing == null) return;
      await isar.writeTxn(() async {
        await isar.draftModels.delete(existing.id);
      });
      return;
    }

    // Decrypt + parse inner draft event.
    Map<String, dynamic> inner;
    try {
      final plain = await Nip44.decryptMessage(
        event.content,
        activePrivkey!,
        activePubkey!,
      );
      inner = jsonDecode(plain) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final innerContent = (inner['content'] as String?) ?? '';
    final innerTags = (inner['tags'] as List?) ?? const [];
    final eTagRefs = <String>[];
    final pTagRefs = <String>[];
    final tTags = <String>[];
    final draftRefIds = <String>[];
    String? rootEventId;
    String? replyToEventId;
    String? publishedAsEventId;
    for (final raw in innerTags) {
      if (raw is! List || raw.isEmpty) continue;
      final name = raw[0];
      if (name == 'e' && raw.length >= 2) {
        final id = raw[1] as String;
        final marker = raw.length >= 4 ? raw[3] as String? : null;
        if (marker == 'root') rootEventId = id;
        if (marker == 'reply') replyToEventId = id;
        eTagRefs.add(id);
      } else if (name == 'p' && raw.length >= 2) {
        pTagRefs.add(raw[1] as String);
      } else if (name == 't' && raw.length >= 2) {
        tTags.add(raw[1] as String);
      } else if (name == 'd-ref' && raw.length >= 2) {
        draftRefIds.add(raw[1] as String);
      } else if (name == 'published-as' && raw.length >= 2) {
        publishedAsEventId = raw[1] as String;
      }
    }

    try {
      await isar.writeTxn(() async {
        final row = existing ?? DraftModel();
        row.draftId = draftId;
        row.content = innerContent;
        row.rootEventId = rootEventId;
        row.replyToEventId = replyToEventId;
        row.eTagRefs = eTagRefs;
        row.pTagRefs = pTagRefs;
        row.tTags = tTags;
        row.draftRefIds = draftRefIds;
        row.publishedAsEventId = publishedAsEventId;
        // Preserve original local createdAt if we already have the row.
        row.createdAt = existing?.createdAt ?? incomingCreatedAt;
        row.updatedAt = incomingCreatedAt;
        row.lastSyncedCreatedAt = incomingCreatedAt;
        row.lastSyncedEventId = event.id;
        await isar.draftModels.put(row);
      });
    } catch (_) {
      return;
    }

    // Cross-device publish reconciliation: when a draft arrives as a
    // tombstone (`published-as` set), sweep any local drafts whose
    // `draftRefIds` still hold this UUID and rewrite UUID → event id into
    // their `eTagRefs`. Republishing the swept drafts here would loop with
    // other devices; the next user save / publish will carry the corrected
    // refs onward.
    if (publishedAsEventId != null) {
      try {
        final referencing = await isar.draftModels
            .filter()
            .draftRefIdsElementEqualTo(draftId)
            .findAll();
        if (referencing.isNotEmpty) {
          final eid = publishedAsEventId;
          await isar.writeTxn(() async {
            for (final d in referencing) {
              d.draftRefIds = d.draftRefIds.where((r) => r != draftId).toList();
              if (!d.eTagRefs.contains(eid)) {
                d.eTagRefs = [...d.eTagRefs, eid];
              }
              d.updatedAt = DateTime.now();
              await isar.draftModels.put(d);
            }
          });
        }
      } catch (_) {
        // Sweep is best-effort.
      }
    }
  }

  String? _firstTagValue(List rawTags, String name) {
    for (final raw in rawTags) {
      if (raw is! List || raw.length < 2) continue;
      if (raw[0] == name) return raw[1] as String?;
    }
    return null;
  }
}
