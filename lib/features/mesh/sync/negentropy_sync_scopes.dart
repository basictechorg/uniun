import 'package:isar_community/isar.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';

import 'mesh_event_codec.dart';
import 'scopes/blocked_user_sync_scope.dart';
import 'scopes/dm_conversation_sync_scope.dart';
import 'scopes/followed_note_sync_scope.dart';
import 'scopes/followed_user_sync_scope.dart';
import 'scopes/gana_sync_scope.dart';
import 'scopes/group_sync_scope.dart';
import 'scopes/manas_member_sync_scope.dart';
import 'scopes/manas_sync_scope.dart';
import 'scopes/private_group_sync_scope.dart';
import 'scopes/private_note_sync_scope.dart';
import 'scopes/public_event_sync_scope.dart';
import 'scopes/saved_note_sync_scope.dart';
import 'scopes/signed_note_sync_scope.dart';
import 'sync_scope.dart';

/// Every same-identity collection, reconciled by [Nip77Reconciler] as signed
/// Nostr events over one pooled NIP-77 negentropy tree. This is the sole
/// same-identity sync path (the legacy id-list `TrustedSyncEngine` was removed).
///
/// - SavedNote (30500), FollowedNote (30501), BlockedUser (30502),
///   DmConversation (30503), FollowedUser (30505), Manas (30510),
///   ManasMember (30511), Gana (30520), Group (30540), PrivateGroup (30541) —
///   NIP-44 self-encrypted addressable records (via `MeshRecordSyncScope`).
/// - Kind 0 (profile) via [PublicEventSyncScope] — public relay events
///   forwarded verbatim (not encrypted).
/// - Kind 1 (feed) + Kind 42 (public channel) via [SignedNoteSyncScope] — real
///   signed events forwarded verbatim.
/// - Kind 14/15 (DM) + Kind 9023 (private channel) via [PrivateNoteSyncScope] —
///   the fabricated Kind-30530 self-encrypted plaintext wrapper.
///
/// (Kind 30504 LocalHide / DeletedNote was removed in Phase 6 — hiding a note is
/// a device-local UI preference, not a cross-device intent.)
List<NegentropySyncScope> buildNegentropySyncScopes({
  required Isar isar,
  required MeshEventCodec codec,
  required NoteRelationRepository relations,
  String? activePubkeyHex,
}) {
  return [
    SavedNoteSyncScope(isar, codec),
    FollowedNoteSyncScope(isar, codec),
    BlockedUserSyncScope(isar, codec),
    DmConversationSyncScope(isar, codec),
    PublicEventSyncScope(isar, activePubkeyHex: activePubkeyHex),
    FollowedUserSyncScope(isar, codec),
    SignedNoteSyncScope(isar, activePubkeyHex: activePubkeyHex),
    PrivateNoteSyncScope(
      isar,
      codec,
      relations,
      activePubkeyHex: activePubkeyHex,
    ),
    ManasSyncScope(isar, codec),
    ManasMemberSyncScope(isar, codec),
    GanaSyncScope(isar, codec),
    GroupSyncScope(isar, codec),
    PrivateGroupSyncScope(isar, codec),
  ];
}
