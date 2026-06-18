import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/draft_model.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/saved_note_model.dart';

/// One note prepared for prompt packing. Source-agnostic — saved, own, and
/// draft notes are all flattened to this shape after resolution.
class PackedNote {
  final String id;
  final String content;
  final DateTime created;
  final PackedNoteSource source;

  const PackedNote({
    required this.id,
    required this.content,
    required this.created,
    required this.source,
  });
}

enum PackedNoteSource { saved, own, draft }

/// Resolves a multi-Manas membership set into a token-budgeted, newest-first
/// list of packed notes for prompt construction.
///
/// Lives in the engine isolate — no Flutter imports, only `isar_community`.
/// Pure-Dart, called from `GanaEngine._runOnce()`.
class ManasContextLoader {
  /// Approximation — most tokenizers average ~4 chars / token for English.
  /// We pad with a 15% safety margin in [merge] to absorb structural prompt
  /// overhead (headers, tool definitions, separators).
  static const int _charsPerTokenEstimate = 4;
  static const double _safetyMargin = 0.85;

  /// Build the context for a Gana. Set semantics: a note that appears in
  /// multiple of the requested Manases is included once.
  ///
  /// [budget] is in tokens — caller passes the model's max context minus
  /// the budget reserved for the task prompt + input + output.
  static Future<List<PackedNote>> merge({
    required Isar isar,
    required List<String> manasIds,
    required int budget,
  }) async {
    if (manasIds.isEmpty || budget <= 0) return const [];

    final effectiveCharBudget =
        (budget * _charsPerTokenEstimate * _safetyMargin).floor();

    // 1. Collect the union of note ids across all selected Manases.
    final unique = <String>{};
    for (final mid in manasIds) {
      final links = await isar.manasNoteLinkModels
          .filter()
          .manasIdEqualTo(mid)
          .findAll();
      unique.addAll(links.map((l) => l.noteId));
    }
    if (unique.isEmpty) return const [];

    // 2. Resolve each id across saved → notes → drafts (first hit wins).
    //    Single-id lookups; we lean on Isar's unique index on each table.
    final resolved = <PackedNote>[];
    for (final id in unique) {
      final p = await _resolve(isar, id);
      if (p != null) resolved.add(p);
    }

    // 3. Sort by created desc, pack until the char budget is spent.
    resolved.sort((a, b) => b.created.compareTo(a.created));
    final packed = <PackedNote>[];
    var used = 0;
    for (final n in resolved) {
      final cost = n.content.length;
      if (used + cost > effectiveCharBudget) {
        // If a single note exceeds the remaining budget, skip rather than
        // truncate — partial content can change meaning. The next-smaller
        // note in the sorted list may still fit.
        continue;
      }
      packed.add(n);
      used += cost;
    }
    return packed;
  }

  static Future<PackedNote?> _resolve(Isar isar, String id) async {
    // Saved is the primary store for Manas membership today, so try it first.
    final saved =
        await isar.savedNoteModels.filter().eventIdEqualTo(id).findFirst();
    if (saved != null) {
      return PackedNote(
        id: saved.eventId,
        content: saved.content,
        created: saved.created,
        source: PackedNoteSource.saved,
      );
    }
    // Own notes share the eventId index.
    final own = await isar.noteModels.filter().eventIdEqualTo(id).findFirst();
    if (own != null) {
      return PackedNote(
        id: own.eventId,
        content: own.content,
        created: own.created,
        source: PackedNoteSource.own,
      );
    }
    // Drafts use draftId (UUID, never collides with hex event ids).
    final draft =
        await isar.draftModels.filter().draftIdEqualTo(id).findFirst();
    if (draft != null) {
      return PackedNote(
        id: draft.draftId,
        content: draft.content,
        created: draft.createdAt,
        source: PackedNoteSource.draft,
      );
    }
    return null;
  }
}
