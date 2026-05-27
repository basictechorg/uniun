import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 1 — short text note.
///
/// Persists to [NoteModel] (idempotent), increments [NoteModel.cachedReplyCount]
/// on the direct parent + non-root mention refs, and bumps
/// [FollowedNoteModel.newReferenceCount] for any followed root referenced.
class Kind1NoteHandler implements KindHandler {
  @override
  Set<int> get kinds => const {1};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final eventId = event['id'] as String?;
    if (eventId == null) return;

    final model = _parseNoteModel(event);

    try {
      await isar.writeTxn(() async {
        final existing = await isar.noteModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await isar.noteModels.put(model);

        // Increment direct parent + mention-refs. Exclude root-tag when it
        // differs from replyToEventId so nested thread replies don't inflate
        // the root note's count.
        final toIncrement = <String>{};
        if (model.replyToEventId != null) {
          toIncrement.add(model.replyToEventId!);
        }
        for (final ref in model.eTagRefs) {
          if (ref != model.rootEventId && ref != model.replyToEventId) {
            toIncrement.add(ref);
          }
        }
        for (final refId in toIncrement) {
          final ref = await isar.noteModels
              .where()
              .eventIdEqualTo(refId)
              .findFirst();
          if (ref != null) {
            ref.cachedReplyCount++;
            await isar.noteModels.put(ref);
          }
        }
      });
    } catch (_) {
      return;
    }

    await _bumpFollowedReferenceCountsIfNeeded(event, isar);
  }

  Future<void> _bumpFollowedReferenceCountsIfNeeded(
    Map<String, dynamic> event,
    Isar isar,
  ) async {
    final incomingId = event['id'] as String?;
    if (incomingId == null || incomingId.isEmpty) return;

    final eRefs = EventParser.eTagIds(event);
    if (eRefs.isEmpty) return;

    final followed = await isar.followedNoteModels.where().findAll();
    if (followed.isEmpty) return;

    final followedRoots = followed.map((f) => f.eventId).toSet();
    final refsToIncrement = <String>{};
    for (final ref in eRefs) {
      if (!followedRoots.contains(ref)) continue;
      if (ref == incomingId) continue;
      refsToIncrement.add(ref);
    }
    if (refsToIncrement.isEmpty) return;

    await isar.writeTxn(() async {
      for (final ref in refsToIncrement) {
        final fresh = await isar.followedNoteModels
            .where()
            .eventIdEqualTo(ref)
            .findFirst();
        if (fresh == null) continue;
        fresh.newReferenceCount = fresh.newReferenceCount + 1;
        await isar.followedNoteModels.put(fresh);
      }
    });
  }

  NoteModel _parseNoteModel(Map<String, dynamic> event) {
    final rawTags = (event['tags'] as List<dynamic>? ?? []);

    String? rootEventId;
    String? replyToEventId;
    final eTagRefs = <String>[];
    final pTagRefs = <String>[];
    final tTags = <String>[];

    for (final rawTag in rawTags) {
      if (rawTag is! List || rawTag.isEmpty) continue;
      final tagName = rawTag[0] as String?;
      if (tagName == null || rawTag.length < 2) continue;

      switch (tagName) {
        case 'e':
          final tagId = rawTag[1] as String;
          eTagRefs.add(tagId);
          if (rawTag.length > 3) {
            final marker = rawTag[3] as String?;
            if (marker == 'root') rootEventId = tagId;
            if (marker == 'reply') replyToEventId = tagId;
          }
        case 'p':
          pTagRefs.add(rawTag[1] as String);
        case 't':
          tTags.add(rawTag[1] as String);
      }
    }

    return NoteModel(
      eventId: event['id'] as String,
      sig: event['sig'] as String? ?? '',
      authorPubkey: event['pubkey'] as String? ?? '',
      content: event['content'] as String? ?? '',
      type: NoteType.text,
      eTagRefs: eTagRefs,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      pTagRefs: pTagRefs,
      tTags: tTags,
      created: EventParser.dateTimeFromSec(event['created_at'] as int? ?? 0),
      isSeen: false,
    );
  }
}
