import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../mesh_event_codec.dart';
import '../sync_scope.dart';
import 'signed_event_peek.dart';

/// Shared base for the seven private "mesh record" scopes — the per-user
/// collections synced as signed + NIP-44-self-encrypted addressable Nostr
/// events (Kinds 3050x/3051x/3052x): SavedNote, FollowedNote, BlockedUser,
/// DmConversation, Manas, ManasMember, Gana.
///
/// Every one of these scopes did the exact same thing — scan signed rows →
/// peek id/created_at → LWW-compare → verify via [MeshEventCodec] → apply the
/// decoded body → stamp the signed event + tombstone — differing ONLY in the
/// Isar collection, the mesh [meshKind], and the `d`-tag → row lookup. This
/// base owns the shared machinery; a concrete scope is a handful of thin
/// binding hooks.
///
/// It implements [NegentropySyncScope] only — these scopes never speak the
/// legacy id-list protocol, so (unlike the old `SyncScope`) there are no
/// legacy no-op stubs to satisfy.
///
/// ## Run-scoped lookup memo
///
/// The reconciler always calls [localIndex] for every scope at the start of a
/// round (to build the fingerprint tree) BEFORE it ever calls [signedEvent]
/// (which only happens later, for ids the peer asked for). The set of ids a
/// peer can request is exactly the set we advertised in [localIndex]. So we
/// stash `id → signedJson` while scanning in [localIndex] and serve
/// [signedEvent] from that map — turning what used to be a full-table scan
/// *per requested id* into a single scan *per round*. A [signedEvent] call
/// with no preceding [localIndex] (e.g. a unit test) still works via a
/// full-scan fallback. The memo is rebuilt on every [localIndex] so it can
/// never go stale between rounds.
abstract class MeshRecordSyncScope<T> implements NegentropySyncScope {
  MeshRecordSyncScope(this.isar, this.codec);

  @protected
  final Isar isar;
  @protected
  final MeshEventCodec codec;

  Map<String, String>? _runIndex;

  // ── Binding hooks each concrete scope provides ──────────────────────────

  /// The mesh event kind this scope owns (e.g. [MeshEventKinds.savedNote]).
  int get meshKind;

  /// Every row that currently carries a signed mesh event.
  Future<List<T>> signedRows();

  /// The signed Nostr event JSON stored on [row] (never null for a
  /// [signedRows] element; may be null for a [findExisting] result).
  String? signedJsonOf(T row);

  /// Resolve the row addressed by an incoming [record] (via its `d` tag), or
  /// null if this device holds none yet.
  Future<T?> findExisting(MeshEventRecord record);

  /// Decode [record] into a row (reusing [existing] when present). Return null
  /// to drop the record without error (e.g. a malformed composite `d` tag).
  /// Throwing is also caught and dropped (logged as "body malformed").
  T? applyRecord(MeshEventRecord record, T? existing);

  /// Persist [row] within the caller's write transaction.
  Future<void> putRow(T row);

  /// Stamp the wire event + tombstone state onto [row] before it is put.
  void stampSigned(T row, String signedJson, DateTime? removedAt);

  // ── NegentropySyncScope: read side ──────────────────────────────────────

  @override
  Future<Map<String, int>> localIndex() async {
    final index = <String, String>{};
    final out = <String, int>{};
    for (final row in await signedRows()) {
      final json = signedJsonOf(row);
      if (json == null) continue;
      final peeked = SignedEventPeek.tryPeek(json);
      if (peeked == null) continue;
      out[peeked.id] = peeked.createdAt;
      index[peeked.id] = json;
    }
    _runIndex = index;
    return out;
  }

  @override
  Future<String?> signedEvent(String eventId) async {
    final memo = _runIndex;
    if (memo != null) return memo[eventId];
    // Fallback: a caller that skipped localIndex(). Full scan + peek.
    for (final row in await signedRows()) {
      final json = signedJsonOf(row);
      if (json == null) continue;
      final peeked = SignedEventPeek.tryPeek(json);
      if (peeked != null && peeked.id == eventId) return json;
    }
    return null;
  }

  // ── NegentropySyncScope: write side ─────────────────────────────────────

  @override
  Future<void> upsertSigned(String signedEventJson) async {
    late final MeshEventRecord record;
    try {
      record = await codec.openRecord(signedEventJson);
    } catch (e) {
      debugPrint('MESH/SYNC: $name codec reject: $e');
      return;
    }
    if (record.kind != meshKind) return; // not our scope

    await isar.writeTxn(() async {
      final existing = await findExisting(record);

      // LWW (plan §5a): keep the local row when its event is newer, or has an
      // equal created_at with a lexicographically-higher id.
      //
      // A row with no signed event yet — a fresh local edit not signed at this
      // instant, or a migration-backfilled row — has nothing to compare, so
      // the first incoming event always wins. That is acceptable: an unsigned
      // row was never advertised on the mesh, so no peer is relying on it, and
      // the local user's next mutation re-signs it with a fresh created_at.
      final localJson = existing == null ? null : signedJsonOf(existing);
      if (localJson != null) {
        final localPeek = SignedEventPeek.tryPeek(localJson);
        if (localPeek != null) {
          if (localPeek.createdAt > record.createdAt) return;
          if (localPeek.createdAt == record.createdAt &&
              localPeek.id.compareTo(
                    SignedEventPeek.tryPeek(signedEventJson)?.id ?? '',
                  ) >=
                  0) {
            return;
          }
        }
      }

      T? row;
      try {
        row = applyRecord(record, existing);
      } catch (e) {
        debugPrint('MESH/SYNC: $name body malformed: $e');
        return;
      }
      if (row == null) return; // scope chose to drop this record

      stampSigned(
        row,
        signedEventJson,
        record.state == MeshRecordState.removed ? DateTime.now() : null,
      );
      await putRow(row);
    });
  }
}
