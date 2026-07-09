/// A reconcilable collection presented to the mesh reconciler as a set of
/// signed Nostr events. The reconciler never interprets a scope's rows beyond
/// their `(eventId, created_at)` fingerprint; it only diffs what each side holds
/// and ships the signed event JSONs the peer is missing, keeping reconciliation
/// content-addressed and idempotent.
///
/// Every same-identity scope implements this single contract and is consumed by
/// `Nip77Reconciler` over the NIP-77 negentropy fingerprint exchange. Scopes
/// come in two flavours, both speaking this interface:
///
///   * **self-encrypted addressable records** (`MeshRecordSyncScope`) — saves,
///     follows, blocks, DM conversations, Manases, Ganas, and the DM /
///     private-channel note wrapper (`privateNote`, kind 30530);
///   * **verbatim real events** — `PublicEventSyncScope` (kind 0/3) and
///     `SignedNoteSyncScope` (kind 1/42), which forward the author's real signed
///     event as-is.

/// NIP-77 negentropy scope (`Nip77Reconciler`). See the library doc above.
abstract class NegentropySyncScope {
  /// Stable scope identifier on the wire (e.g. 'savedNote', 'publicEvent').
  String get name;

  /// Every mesh-syncable row this device holds, as `eventId → createdAt`
  /// (unix seconds). Feeds the reconciliation fingerprint tree.
  Future<Map<String, int>> localIndex();

  /// Wire form (signed Nostr event JSON) of one row keyed by [eventId], or
  /// null if the row is missing. The reconciler forwards it verbatim to the
  /// peer.
  Future<String?> signedEvent(String eventId);

  /// Verifies + decrypts + LWW-applies one signed event received from a peer.
  Future<void> upsertSigned(String signedEventJson);
}
