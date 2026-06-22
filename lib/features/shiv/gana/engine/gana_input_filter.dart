import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';

/// Per-type input fetcher for the Gana engine.
///
/// Encodes the cursor + self-loop guards from `ganas.md` §2.4.5:
///   1. `created > lastProcessedCreated` (monotonic cursor)
///   2. `authorPubkey != selfPubkey` (no self-loops on own publishes)
///   3. `eventId NOT IN selfOutputs` (no replies to our own Gana output)
///   4. same-second tiebreak: drop the row whose id equals
///      `lastProcessedEventId`
///
/// Returns up to [_capPerRun] notes, sorted oldest-first so the prompt
/// shows them in chronological order even though Isar returns newest-first
/// internally.
class GanaInputFilter {
  static const int _capPerRun = 20;

  /// Returns an empty list for standalone Ganas (no input surface). The
  /// engine treats that as "fall through, run on schedule alone."
  static Future<List<NoteModel>> fetch({
    required Isar isar,
    required GanaEntity gana,
    required String selfPubkeyHex,
    required Set<String> selfOutputEventIds,
  }) async {
    if (gana.inputType == null) return const [];

    final after = gana.lastProcessedCreated ??
        DateTime.fromMillisecondsSinceEpoch(0);

    // Each branch hits a different indexed column. Isar's filter is
    // builder-style. The self-author filter (NOT equal) is applied
    // post-query — Isar 3 has no first-class `not equal` for ordering
    // filters, so we over-fetch slightly and drop self rows in Dart.
    final fetchCap = _capPerRun * 2;
    List<NoteModel> rows = const [];
    switch (gana.inputType!) {
      case GanaInputType.channel:
        rows = await isar.noteModels
            .filter()
            .channelIdEqualTo(gana.inputRefId)
            .kindEqualTo(kChannelMessageKind)
            .createdGreaterThan(after)
            .sortByCreatedDesc()
            .limit(fetchCap)
            .findAll();
        break;
      case GanaInputType.privateChannel:
        rows = await isar.noteModels
            .filter()
            .groupIdEqualTo(gana.inputRefId)
            .kindEqualTo(kPrivateChannelKind)
            .createdGreaterThan(after)
            .sortByCreatedDesc()
            .limit(fetchCap)
            .findAll();
        break;
      case GanaInputType.dm:
        final convId = int.tryParse(gana.inputRefId ?? '');
        if (convId == null) return const [];
        rows = await isar.noteModels
            .filter()
            .conversationIdEqualTo(convId)
            .createdGreaterThan(after)
            .sortByCreatedDesc()
            .limit(fetchCap)
            .findAll();
        break;
      case GanaInputType.user:
        // User-input is nonsense when the user IS self — the engine still
        // applies the self-pubkey drop below as a defensive measure.
        rows = await isar.noteModels
            .filter()
            .authorPubkeyEqualTo(gana.inputRefId ?? '')
            .kindEqualTo(kNoteKind)
            .createdGreaterThan(after)
            .sortByCreatedDesc()
            .limit(fetchCap)
            .findAll();
        break;
      case GanaInputType.followedNote:
        rows = await isar.noteModels
            .filter()
            .eTagRefsElementEqualTo(gana.inputRefId ?? '')
            .kindEqualTo(kNoteKind)
            .createdGreaterThan(after)
            .sortByCreatedDesc()
            .limit(fetchCap)
            .findAll();
        break;
    }

    // Drop self-authored rows — kills self-loops + Gana-to-Gana ping-pong.
    rows = rows.where((r) => r.authorPubkey != selfPubkeyHex).toList();
    if (rows.length > _capPerRun) rows = rows.sublist(0, _capPerRun);

    // Same-second tiebreak — Isar's `createdGreaterThan` is strict, but if
    // multiple rows share `lastProcessedCreated` the strict filter could
    // miss them. Caller already advances the cursor inclusive of the last
    // event id, so we drop the duplicate here just in case the timestamp
    // bucket happens to overlap.
    final lastId = gana.lastProcessedEventId;
    if (lastId != null && rows.isNotEmpty && rows.last.eventId == lastId) {
      rows = rows.sublist(0, rows.length - 1);
    }

    // Self-loop guard #2: drop any row whose id is in our own output history.
    if (selfOutputEventIds.isNotEmpty) {
      rows = rows
          .where((r) => !selfOutputEventIds.contains(r.eventId))
          .toList();
    }

    // Return oldest-first for prompt readability.
    return rows.reversed.toList();
  }

  /// Walks up to [_replyAncestryDepth] ancestors of [note] via
  /// `replyToEventId`. Returns the chain newest-first (immediate parent
  /// first). Used to add reply context to the prompt without flooding it.
  static const int _replyAncestryDepth = 2;

  static Future<List<NoteModel>> ancestry({
    required Isar isar,
    required NoteModel note,
  }) async {
    final chain = <NoteModel>[];
    String? cursor = note.replyToEventId;
    var hops = 0;
    while (cursor != null && hops < _replyAncestryDepth) {
      final parent = await isar.noteModels
          .filter()
          .eventIdEqualTo(cursor)
          .findFirst();
      if (parent == null) break;
      chain.add(parent);
      cursor = parent.replyToEventId;
      hops += 1;
    }
    return chain;
  }
}
