import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/data/models/notes/imeta_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 42 — NIP-28 channel message.
///
/// Tag walk picks out root/reply e-tags via NIP-10 markers. Falls back to
/// positional first/last when markers are absent (legacy NIP-10).
class Kind42Handler implements KindHandler {
  Kind42Handler({required this.activePubkey});

  /// The signed-in user's pubkey (hex) — own messages get no unread row.
  final String? activePubkey;

  @override
  Set<int> get kinds => const {42};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final sig = event['sig'] as String?;
    final content = event['content'] as String?;
    final createdAtSec = event['created_at'] as int?;

    if (eventId == null ||
        pubkey == null ||
        sig == null ||
        content == null ||
        createdAtSec == null) {
      return;
    }

    final tags = event['tags'] as List<dynamic>? ?? [];
    String? channelId;
    String? replyEventId;
    String? embeddedNoteJson;
    final eTagRefs = <String>[];

    for (final tag in tags) {
      if (tag is! List || tag.isEmpty) continue;
      if (tag[0] == 'e') {
        final eRef = tag[1] as String?;
        if (eRef != null) {
          eTagRefs.add(eRef);
          final marker = tag.length > 3 ? tag[3] as String? : null;
          if (marker == 'root') {
            channelId = eRef;
          } else if (marker == 'reply') {
            replyEventId = eRef;
          }
        }
      } else if (tag[0] == EmbeddedNoteCodec.tagName && tag.length >= 2) {
        // Embed-by-value share — verify the snapshot once, here at the edge.
        embeddedNoteJson =
            EmbeddedNoteCodec.verifyAndSanitize(tag[1] as String);
      }
    }

    if (channelId == null && eTagRefs.isNotEmpty) channelId = eTagRefs.first;
    if (replyEventId == null && eTagRefs.length > 1) {
      replyEventId = eTagRefs.last;
    }
    if (channelId == null) return;

    final model = NoteModel(
      eventId: eventId,
      sig: sig,
      authorPubkey: pubkey,
      content: content,
      kind: kChannelMessageKind,
      channelId: channelId,
      type: NoteType.text,
      eTagRefs: eTagRefs,
      rootEventId: channelId,
      replyToEventId: replyEventId,
      pTagRefs: const [],
      tTags: const [],
      created: EventParser.dateTimeFromSec(createdAtSec),
      embeddedNoteJson: embeddedNoteJson,
      attachments: ImetaParser.parseAsAttachments(event),
    );

    try {
      await isar.writeTxn(() async {
        final existing = await isar.noteModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await isar.noteModels.put(model);

        // Unread row for messages from other users (own sends are pre-seen).
        if (pubkey != activePubkey) {
          await putUnreadRowInTxn(isar, model);
        }

        // Reference edges: reply target + mentions, minus the channel root.
        // Unique (parentId, childId) index keeps re-delivery idempotent.
        final parents = replyEdgeParentIds(
          replyToEventId: replyEventId,
          rootEventId: channelId,
          eTagRefs: eTagRefs,
        );
        for (final parentId in parents) {
          await isar.noteRelationModels.put(
            NoteRelationModel()
              ..parentId = parentId
              ..childId = eventId
              ..createdAt = EventParser.dateTimeFromSec(createdAtSec),
          );
        }
      });
    } catch (_) {
      return;
    }
  }
}
