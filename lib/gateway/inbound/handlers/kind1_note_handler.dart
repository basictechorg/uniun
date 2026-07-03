import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/data/models/notes/imeta_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 1 — short text note.
///
/// Persists to [NoteModel] (idempotent), records reference edges in
/// [NoteRelationModel] for the direct parent + non-root mention refs, and
/// inserts an unread row for non-own notes. The followed-note "new refs"
/// badge is derived at read-time by `FollowedNoteRepository` from the
/// relation edges — this handler does not touch `FollowedNoteModel`.
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
  }

  NoteModel _parseNoteModel(Map<String, dynamic> event) {
    final rawTags = (event['tags'] as List<dynamic>? ?? []);

    String? rootEventId;
    String? replyToEventId;
    String? embeddedNoteJson;
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
        case EmbeddedNoteCodec.tagName:
          // Embed-by-value share — verify the snapshot once, here at the edge.
          embeddedNoteJson =
              EmbeddedNoteCodec.verifyAndSanitize(rawTag[1] as String);
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
      embeddedNoteJson: embeddedNoteJson,
      attachments: ImetaParser.parseAsAttachments(event),
    );
  }
}
