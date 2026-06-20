import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/data/models/draft_model.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/features/shiv/rag/embedding/embedding_service.dart';
import 'package:uniun/features/shiv/rag/retrieval/vector_search_service.dart';

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

/// Resolves a multi-Manas membership set into a token-budgeted list of
/// packed notes for prompt construction.
///
/// Two ranking modes, chosen automatically by [merge]:
///
///   • **By relevance** — when [relevanceQuery] is non-null/non-empty.
///     The query is embedded, the existing vector index is searched, and
///     hits are *intersected* with the Manas membership set. Best for
///     reactive Ganas that are responding to a specific input message
///     (channel reply, DM reply, etc.).
///
///   • **Newest-first** — fallback. Used for standalone Ganas with no
///     input to rank against. Same behavior as the original loader.
///
/// Runs entirely in the main isolate (engine moved here 2026-06-20), so
/// it can lean on the existing [EmbeddingService] / [VectorSearchService]
/// singletons without crossing isolate boundaries.
class ManasContextLoader {
  /// Most tokenizers average ~4 chars / token for English. Pad with a
  /// 15% safety margin to absorb prompt overhead (headers, separators).
  static const int _charsPerTokenEstimate = 4;
  static const double _safetyMargin = 0.85;

  /// How many vector hits to consider before intersecting with the Manas
  /// set. The intersection can be small, so we pull a generous pool.
  static const int _vectorPoolSize = 50;

  /// Build the context for a Gana. Set semantics: a note that appears in
  /// multiple of the requested Manases is included once.
  ///
  /// [budget] is in tokens — caller passes the model's max context minus
  /// the budget reserved for the task prompt + input + output.
  ///
  /// [relevanceQuery] (optional) — when present, rank Manas notes by
  /// cosine similarity to this text. When null, fall back to newest-first.
  static Future<List<PackedNote>> merge({
    required Isar isar,
    required List<String> manasIds,
    required int budget,
    String? relevanceQuery,
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

    // 2a. By-relevance path — embed query, search vectors, intersect.
    if (relevanceQuery != null && relevanceQuery.trim().isNotEmpty) {
      final byRelevance = await _packByRelevance(
        isar: isar,
        query: relevanceQuery,
        allowedNoteIds: unique,
        charBudget: effectiveCharBudget,
      );
      if (byRelevance != null) return byRelevance;
      // Embedder/vector unavailable → fall through to newest-first.
    }

    // 2b. Newest-first path.
    return _packByNewest(
      isar: isar,
      noteIds: unique,
      charBudget: effectiveCharBudget,
    );
  }

  // ── By-relevance ───────────────────────────────────────────────────────

  static Future<List<PackedNote>?> _packByRelevance({
    required Isar isar,
    required String query,
    required Set<String> allowedNoteIds,
    required int charBudget,
  }) async {
    try {
      final embedder = getIt<EmbeddingService>();
      final searcher = getIt<VectorSearchService>();
      // `embed()` lazily calls `init()` internally if not ready.
      final vec = await embedder.embed(query);
      if (vec.isEmpty) return null;

      final hits = await searcher.search(
        queryVector: vec,
        topK: _vectorPoolSize,
        minScore: 0.0, // we'll filter by Manas membership, not score
      );
      if (hits.isEmpty) return null;

      // Intersect with the Manas membership set; preserve search order
      // (already sorted by score desc).
      final ordered = <PackedNote>[];
      final seen = <String>{};
      for (final h in hits) {
        if (!allowedNoteIds.contains(h.noteId)) continue;
        if (!seen.add(h.noteId)) continue;
        // Search returns content too — but resolve through saved/own/draft
        // to get accurate `created` for the prompt date stamp.
        final p = await _resolve(isar, h.noteId);
        if (p != null) ordered.add(p);
      }
      if (ordered.isEmpty) return null;

      // Pack under budget — keep high-score first; skip oversize entries
      // rather than truncate (truncation changes meaning).
      final packed = <PackedNote>[];
      var used = 0;
      for (final n in ordered) {
        final cost = n.content.length;
        if (used + cost > charBudget) continue;
        packed.add(n);
        used += cost;
      }
      return packed;
    } catch (e, st) {
      // Vector path is best-effort. Any failure (no embedder model, no
      // vector index yet, etc.) falls back to newest-first below.
      debugPrint('ManasContextLoader: vector retrieval failed, falling '
          'back to newest-first: $e\n$st');
      return null;
    }
  }

  // ── By newest-first (fallback) ─────────────────────────────────────────

  static Future<List<PackedNote>> _packByNewest({
    required Isar isar,
    required Set<String> noteIds,
    required int charBudget,
  }) async {
    final resolved = <PackedNote>[];
    for (final id in noteIds) {
      final p = await _resolve(isar, id);
      if (p != null) resolved.add(p);
    }
    resolved.sort((a, b) => b.created.compareTo(a.created));
    final packed = <PackedNote>[];
    var used = 0;
    for (final n in resolved) {
      final cost = n.content.length;
      if (used + cost > charBudget) continue;
      packed.add(n);
      used += cost;
    }
    return packed;
  }

  // ── Resolution ─────────────────────────────────────────────────────────

  static Future<PackedNote?> _resolve(Isar isar, String id) async {
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
    final own = await isar.noteModels.filter().eventIdEqualTo(id).findFirst();
    if (own != null) {
      return PackedNote(
        id: own.eventId,
        content: own.content,
        created: own.created,
        source: PackedNoteSource.own,
      );
    }
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
