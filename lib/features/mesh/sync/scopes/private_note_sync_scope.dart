import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';

import '../bodies/private_note_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30530 `privateNote` scope — the unsigned note surfaces (DM 14/15,
/// private group 9023) synced as fabricated, NIP-44-self-encrypted addressable
/// events carrying the decrypted plaintext body. Addressable slot `d = eventId`.
///
/// Unlike [SignedNoteSyncScope] (which forwards the real signed event verbatim),
/// these surfaces have no stateless-verifiable original: NIP-17 rumors are
/// deniable/unsigned, and MLS ciphertext needs per-device group state a peer
/// cannot reproduce. So we ship the plaintext body — the peer rebuilds the row
/// without re-decrypting anything. All the shared negentropy machinery lives in
/// [MeshRecordSyncScope]; this binds the collection, the kind, and the note
/// side-effects (unread row + reply edges), and honors local tombstones.
class PrivateNoteSyncScope extends MeshRecordSyncScope<NoteModel> {
  PrivateNoteSyncScope(
    super.isar,
    super.codec,
    this._relations, {
    this.activePubkeyHex,
  });

  final NoteRelationRepository _relations;

  /// Active identity's hex pubkey — own messages skip the unread row.
  final String? activePubkeyHex;

  static const Set<int> _kinds = {
    kDmTextKind,
    kDmFileKind,
    kPrivateGroupKind,
  };

  @override
  String get name => 'privateNote';

  @override
  int get meshKind => MeshEventKinds.privateNote;

  /// Signs any DM / private-group note rows that don't yet carry a wrapper.
  ///
  /// Centralizing signing here (rather than at the three create points) means
  /// the code paths that *make* these rows — inbound DM decrypt, outbound
  /// `sendDm`, and the Marmot MLS receive/send — need no access to the Nostr
  /// nsec (Marmot's background watcher has none). The scope already holds the
  /// [MeshEventCodec], and this runs on the mesh isolate right before the
  /// fingerprint tree is built, so a fresh row becomes mesh-visible on the
  /// first reconciliation after it lands. Best-effort per row.
  Future<void> _signPending() async {
    final pending = await isar.noteModels
        .filter()
      .privateMeshEventJsonIsNull()
        .anyOf(_kinds, (q, int k) => q.kindEqualTo(k))
        .findAll();
    if (pending.isEmpty) return;
    final updates = <NoteModel>[];
    for (final row in pending) {
      try {
        row.privateMeshEventJson = await codec.signRecord(
          kind: MeshEventKinds.privateNote,
          dTag: row.eventId,
          content: PrivateNoteBody.forActive(row),
        );
        updates.add(row);
      } catch (_) {
        // Skip this row; it retries on the next round.
      }
    }
    if (updates.isEmpty) return;
    await isar.writeTxn(() async {
      for (final r in updates) {
        await isar.noteModels.put(r);
      }
    });
  }

  @override
  Future<Map<String, int>> localIndex() async {
    await _signPending();
    return super.localIndex();
  }

  @override
  Future<List<NoteModel>> signedRows() => isar.noteModels
      .filter()
      .privateMeshEventJsonIsNotNull()
      .anyOf(_kinds, (q, int k) => q.kindEqualTo(k))
      .findAll();

  @override
  String? signedJsonOf(NoteModel row) => row.privateMeshEventJson;

  @override
  Future<NoteModel?> findExisting(MeshEventRecord record) =>
      isar.noteModels.where().eventIdEqualTo(record.dTag).findFirst();

  @override
  NoteModel? applyRecord(MeshEventRecord record, NoteModel? existing) =>
      PrivateNoteBody.applyBody(
        record.content,
        eventId: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(NoteModel row) async {
    // Never resurrect a locally-tombstoned note (Feed-Freedom local suppress).
    final tomb = await isar.deletedNoteModels
        .filter()
        .eventIdEqualTo(row.eventId)
        .removedAtIsNull()
        .findFirst();
    if (tomb != null) return;

    final isNew = row.id == Isar.autoIncrement;
    await isar.noteModels.put(row);

    // Unread row for messages from other users (own sends are pre-seen).
    if (isNew && row.authorPubkey != activePubkeyHex) {
      await putUnreadRowInTxn(isar, row);
    }

    // Reply edges: reply target + non-root mentions. Idempotent via the unique
    // (parentId, childId) index.
    final parents = replyEdgeParentIds(
      replyToEventId: row.replyToEventId,
      rootEventId: row.rootEventId,
      eTagRefs: row.eTagRefs,
    );
    await _relations.addEdgesInTxn(parents: parents, childId: row.eventId);
  }

  @override
  void stampSigned(NoteModel row, String signedJson, DateTime? removedAt) {
    // Notes have no `removedAt` column (they're forever; local suppression is
    // tracked separately in DeletedNoteModel). Only the wire event is stamped.
    row.privateMeshEventJson = signedJson;
  }
}
