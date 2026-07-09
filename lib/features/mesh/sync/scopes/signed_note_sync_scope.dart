import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind1_note_handler.dart';
import 'package:uniun/gateway/inbound/handlers/kind42_handler.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../sync_scope.dart';

/// Reconciles the *real signed* notes in the unified `Note` collection — Kind 1
/// (feed) + Kind 42 (public group) — via NIP-77 negentropy (plan §3).
///
/// # Why raw-forward (not a fabricated wrapper)
///
/// Kind 1 / 42 are genuine signed Nostr events, so — exactly like
/// [PublicEventSyncScope] for Kind 0/3 — we forward the raw signed JSON verbatim
/// and every peer verifies it by the standard
/// `id = SHA256(canonical) && Schnorr sig valid && author = pubkey` rule. No
/// self-encryption, no per-`(kind, d)` wrapper. The bytes are the note the
/// author signed, so foreign-authored feed / channel notes verify natively.
///
/// The unsigned surfaces (DM 14/15, private group 9023) cannot ride this path —
/// their wire form is not a stateless-verifiable signed event — so they use the
/// fabricated self-encrypted `PrivateNoteSyncScope` instead.
///
/// # Storage
///
/// Served from [NoteModel.rawEventJson], populated by the relay inbound
/// handlers ([Kind1NoteHandler] / [Kind42Handler]) — the same handlers used as
/// the downstream sink here, so relay-inbound and mesh-inbound converge on the
/// same terminal state (unread rows + reply edges included). A row without
/// `rawEventJson` (e.g. an own note not yet echoed by a relay) is simply not
/// advertised until the raw event lands.
///
/// # Run-scoped lookup memo
///
/// Mirrors [MeshRecordSyncScope]: [localIndex] stashes an `id → rawEventJson`
/// memo so [signedEvent] serves O(1) from it for the ids the peer requests.
///
/// # Tombstones
///
/// A locally-deleted note ([DeletedNoteModel] with `removedAt == null`) is never
/// resurrected — [upsertSigned] drops the incoming event before delegating.
class SignedNoteSyncScope implements NegentropySyncScope {
  SignedNoteSyncScope(
    this._isar, {
    this.activePubkeyHex,
    KindHandler? kind1Handler,
    KindHandler? kind42Handler,
  }) : _kind1 = kind1Handler ?? Kind1NoteHandler(activePubkey: activePubkeyHex),
       _kind42 = kind42Handler ?? Kind42Handler(activePubkey: activePubkeyHex);

  final Isar _isar;
  final KindHandler _kind1;
  final KindHandler _kind42;

  /// The active identity's hex pubkey — forwarded to the inbound handlers so
  /// own notes/messages skip the unread row.
  final String? activePubkeyHex;

  static const Set<int> _kinds = {kNoteKind, kGroupMessageKind};

  Map<String, String>? _runIndex;

  @override
  String get name => 'signedNote';

  @override
  Future<Map<String, int>> localIndex() async {
    final rows = await _isar.noteModels
        .filter()
        .rawEventJsonIsNotNull()
        .anyOf(_kinds, (q, int k) => q.kindEqualTo(k))
        .findAll();
    final index = <String, String>{};
    final out = <String, int>{};
    for (final r in rows) {
      final json = r.rawEventJson;
      if (json == null) continue;
      out[r.eventId] = r.created.millisecondsSinceEpoch ~/ 1000;
      index[r.eventId] = json;
    }
    _runIndex = index;
    return out;
  }

  @override
  Future<String?> signedEvent(String eventId) async {
    final memo = _runIndex;
    if (memo != null) return memo[eventId];
    final row = await _isar.noteModels
        .where()
        .eventIdEqualTo(eventId)
        .findFirst();
    return row?.rawEventJson;
  }

  @override
  Future<void> upsertSigned(String signedEventJson) async {
    late final VerifiedNostrEvent event;
    try {
      final decoded = jsonDecode(signedEventJson);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('MESH/SYNC: signedNote JSON not an object');
        return;
      }
      final verified = const NostrEventVerifier().verify(decoded);
      if (verified == null) {
        debugPrint('MESH/SYNC: signedNote id/sig invalid');
        return;
      }
      event = verified;
    } catch (e) {
      debugPrint('MESH/SYNC: signedNote decode failed: $e');
      return;
    }
    if (!_kinds.contains(event.kind)) return; // not our scope

    // Never resurrect a locally-tombstoned note (Feed-Freedom local suppress).
    final tomb = await _isar.deletedNoteModels
        .filter()
        .eventIdEqualTo(event.id)
        .removedAtIsNull()
        .findFirst();
    if (tomb != null) return;

    switch (event.kind) {
      case kNoteKind:
        await _kind1.handle(event, _isar);
      case kGroupMessageKind:
        await _kind42.handle(event, _isar);
    }

    // Mesh semantics: a note synced from our other device is new to THIS
    // device, so it always gets an unread row — even own notes. The relay
    // inbound handlers skip own-authored notes, which would wrongly suppress
    // them from the feed banner here (same rationale as the legacy
    // NoteSyncScope). Idempotent via the unique eventId index.
    await _isar.writeTxn(() async {
      final note = await _isar.noteModels
          .where()
          .eventIdEqualTo(event.id)
          .findFirst();
      if (note != null) await putUnreadRowInTxn(_isar, note);
    });
  }
}
