/// Nostr event kinds stored in the unified `Note` collection.
///
/// Every user-visible message — feed note, group message, DM, private-group
/// message — lives in one `NoteModel` collection discriminated by [kind].
///   - [kNoteKind]            (1)    short text note (Vishnu feed)
///   - [kGroupMessageKind]  (42)   NIP-28 public group message
///   - [kDmTextKind]          (14)   NIP-17 direct message (text)
///   - [kDmFileKind]          (15)   NIP-17 direct message (file)
///   - [kPrivateGroupKind]  (9023) NIP-29 private group message
///
/// Decrypted MLS payloads for private groups carry no real Nostr kind; we
/// store the wire-envelope kind (9023) as a stable, documented sentinel so the
/// resolver/feed can discriminate them.
const int kNoteKind = 1;
const int kGroupMessageKind = 42;
const int kDmTextKind = 14;
const int kDmFileKind = 15;
const int kPrivateGroupKind = 9023;

/// NIP-37 draft wrap. Parameterized replaceable; `["d", draftId]` keys it. The
/// inner draft event (Kind 1 unsigned payload) is JSON-stringified, NIP-44
/// self-encrypted, and placed in `.content`. Empty content signals deletion.
const int kDraftWrapKind = 31234;

/// NIP-56 report event. Carries `e` (note id) and/or `p` (pubkey) tags whose
/// final positional entry is one of the [ReportType] names. Reports are stored
/// locally in `ReportModel` and broadcast via the event queue; UNIUN does NOT
/// consume incoming reports in v1 (filtering is the relay's or aggregator's
/// concern). Publishers send a report once per (target, type) pair — repeats
/// short-circuit on the unique `eventId` index.
const int kReportKind = 1984;

/// Custom addressable-event kinds UNIUN uses for same-identity mesh sync.
///
/// These never go to a public relay. They are transported peer-to-peer over
/// BLE / LAN inside the same-identity mesh channel, reconciled via NIP-77.
/// Every kind gets a per-record deterministic `d` tag so save/unsave,
/// follow/unfollow, block/unblock, and similar toggles address the same
/// addressable slot instead of creating a new event id each time.
class MeshEventKinds {
  const MeshEventKinds._();

  static const int savedNote = 30500;
  static const int followedNote = 30501;
  static const int blockedUser = 30502;
  static const int dmConversation = 30503;

  // Kind 30504 (LocalHide / DeletedNote) was removed in Phase 6 — local-hide
  // is a device-local UI preference and no longer participates in mesh sync.
  static const int followedUser = 30505;

  static const int manas = 30510;
  static const int manasMember = 30511;
  static const int gana = 30520;

  /// NIP-28 public group membership (kind 40/41 metadata). Addressable slot
  /// `d = groupId`. Synced same-identity over the mesh so a second device on the
  /// same pubkey sees the joined/created group without any relay round-trip.
  static const int group = 30540;

  /// NIP-29 private (MLS/Marmot) group membership. Addressable slot
  /// `d = groupId`. Mirrors the private-group metadata over the mesh so a
  /// second device on the same pubkey sees the joined/created group. Message
  /// bodies still sync via [privateNote] (30530); MLS key material is never
  /// carried here.
  static const int privateGroup = 30541;

  /// The unsigned note surfaces (DM 14/15, private group 9023). Their original
  /// wire form is not a stateless-verifiable signed event (deniable NIP-17
  /// rumors / stateful MLS ciphertext), so the decrypted plaintext body is
  /// carried in this fabricated, NIP-44 self-encrypted addressable event.
  /// `d = eventId`. See `PrivateNoteSyncScope`.
  static const int privateNote = 30530;
}
