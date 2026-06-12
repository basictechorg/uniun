import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/media/media_blob_model.dart';
import 'package:uniun/data/models/media/note_media_ref_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/saved_note_model.dart';

/// Periodic retention sweep — gateway-side, runs every [_interval]. Two
/// phases each tick:
///
/// 1. **Note eviction** — short-lived public traffic (Kind 1 / Kind 42)
///    older than its kind's retention is deleted, unless the note is own
///    (matches the active user's pubkey) or saved (row in [SavedNoteModel]).
///    DMs (14/15), private-channel messages (9023), AI conversations, and
///    profile / channel metadata are untouched here.
///
/// 2. **Media GC** — for every [MediaBlobModel] row that is not pinned and
///    has zero remaining [NoteMediaRefModel] rows, the local file is
///    deleted from `getApplicationSupportDirectory()/media/` and the
///    manifest row is removed. Backend keeps the blob; the next reference
///    can re-download.
///
/// Kept intentionally narrow — better to leave a few extra rows behind
/// than to delete saved content. Future iterations can widen the kind set.
class CleanupManager {
  CleanupManager({required this.isar, required this.activePubkey});

  final Isar isar;
  final String? activePubkey;

  static const Duration _interval = Duration(hours: 6);
  static const Duration _kind1Retention = Duration(days: 7);
  static const Duration _kind42Retention = Duration(days: 3);

  Timer? _timer;
  bool _running = false;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_interval, (_) => unawaited(runOnce()));
    // First sweep on a short delay so we don't fight app launch.
    Future<void>.delayed(const Duration(minutes: 5), runOnce);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> runOnce() async {
    if (_running) return;
    _running = true;
    try {
      await _evictNotes();
      await _gcMedia();
    } catch (e, st) {
      debugPrint('CleanupManager run failed: $e\n$st');
    } finally {
      _running = false;
    }
  }

  // ── Phase 1: note eviction ──────────────────────────────────────────────

  Future<void> _evictNotes() async {
    final now = DateTime.now();
    final kind1Cutoff = now.subtract(_kind1Retention);
    final kind42Cutoff = now.subtract(_kind42Retention);

    final savedIds = (await isar.savedNoteModels.where().findAll())
        .map((s) => s.eventId)
        .toSet();

    final ownPubkey = activePubkey;

    final staleKind1 = await isar.noteModels
        .filter()
        .kindEqualTo(kNoteKind)
        .createdLessThan(kind1Cutoff)
        .findAll();
    final staleKind42 = await isar.noteModels
        .filter()
        .kindEqualTo(kChannelMessageKind)
        .createdLessThan(kind42Cutoff)
        .findAll();
    final stale = [...staleKind1, ...staleKind42];
    if (stale.isEmpty) return;

    final toDelete = <int>[];
    for (final n in stale) {
      if (ownPubkey != null && n.authorPubkey == ownPubkey) continue;
      if (savedIds.contains(n.eventId)) continue;
      toDelete.add(n.id);
    }
    if (toDelete.isEmpty) return;

    await isar.writeTxn(() async {
      await isar.noteModels.deleteAll(toDelete);
    });
  }

  // ── Phase 2: media GC ───────────────────────────────────────────────────

  Future<void> _gcMedia() async {
    final blobs = await isar.mediaBlobModels
        .filter()
        .pinnedEqualTo(false)
        .findAll();
    if (blobs.isEmpty) return;

    final orphanIds = <int>[];
    final orphanPaths = <String>[];
    for (final b in blobs) {
      final refCount = await isar.noteMediaRefModels
          .filter()
          .mediaSha256EqualTo(b.sha256)
          .count();
      if (refCount > 0) continue;
      orphanIds.add(b.id);
      if (b.localPath != null) orphanPaths.add(b.localPath!);
    }
    if (orphanIds.isEmpty) return;

    // Delete files first; if the txn fails we'd otherwise leak rows pointing
    // at deleted files. Errors deleting a file (e.g. permission) shouldn't
    // block the row delete.
    for (final path in orphanPaths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // best-effort
      }
    }

    await isar.writeTxn(() async {
      await isar.mediaBlobModels.deleteAll(orphanIds);
    });
  }
}
