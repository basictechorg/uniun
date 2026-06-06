import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 1 — short text note.
///
/// Persists to [NoteModel] (idempotent), records reference edges in
/// [NoteRelationModel] for the direct parent + non-root mention refs, inserts an
/// unread row for non-own notes, and bumps
/// [FollowedNoteModel.newReferenceCount] for any followed root referenced.
class Kind1NoteHandler implements KindHandler {
  Kind1NoteHandler({required this.activePubkey});

  /// The signed-in user's pubkey (hex) — own notes get no unread row.
  final String? activePubkey;

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

        // Unread row for notes from other users (own notes are already "seen").
        if (model.authorPubkey != activePubkey) {
          await putUnreadRowInTxn(isar, model);
        }

        // Record one reference edge per parent. The unique (parentId, childId)
        // index makes this idempotent against relay re-delivery.
        final parents = replyEdgeParentIds(
          replyToEventId: model.replyToEventId,
          rootEventId: model.rootEventId,
          eTagRefs: model.eTagRefs,
        );
        for (final parentId in parents) {
          await isar.noteRelationModels.put(
            NoteRelationModel()
              ..parentId = parentId
              ..childId = eventId
              ..createdAt = DateTime.now(),
          );
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
    String? quoteEventId;
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
        case 'q':
          // NIP-18 quote tag — first one wins; UI doesn't render multi-quote.
          quoteEventId ??= rawTag[1] as String;
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
      quoteEventId: quoteEventId,
    );
  }
}
