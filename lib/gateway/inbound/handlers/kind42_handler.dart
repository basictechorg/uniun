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
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Kind 42 — NIP-28 group message.
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
  Future<void> handle(VerifiedNostrEvent event, Isar isar) async {
    String? groupId;
    String? replyEventId;
    String? embeddedNoteJson;
    final eTagRefs = <String>[];

    for (final tag in event.tags) {
      if (tag.isEmpty) continue;
      if (tag[0] == 'e') {
        final eRef = tag.length > 1 ? tag[1] : null;
        if (eRef != null) {
          eTagRefs.add(eRef);
          final marker = tag.length > 3 ? tag[3] : null;
          if (marker == 'root') {
            groupId = eRef;
          } else if (marker == 'reply') {
            replyEventId = eRef;
          }
        }
      } else if (tag[0] == EmbeddedNoteCodec.tagName && tag.length >= 2) {
        // Embed-by-value share — verify the snapshot once, here at the edge.
        embeddedNoteJson = EmbeddedNoteCodec.verifyAndSanitize(tag[1]);
      }
    }

    if (groupId == null && eTagRefs.isNotEmpty) groupId = eTagRefs.first;
    if (replyEventId == null && eTagRefs.length > 1) {
      replyEventId = eTagRefs.last;
    }
    if (groupId == null) return;

    final model = NoteModel(
      eventId: event.id,
      sig: event.sig,
      authorPubkey: event.pubkey,
      content: event.content,
      kind: kGroupMessageKind,
      groupId: groupId,
      type: NoteType.text,
      eTagRefs: eTagRefs,
      rootEventId: groupId,
      replyToEventId: replyEventId,
      pTagRefs: const [],
      tTags: const [],
      created: EventParser.dateTimeFromSec(event.createdAt),
      embeddedNoteJson: embeddedNoteJson,
      rawEventJson: event.toCanonicalJson(),
      attachments: ImetaParser.parseAsAttachments(event.toMap()),
    );

    try {
      await isar.writeTxn(() async {
        final existing = await isar.noteModels
            .where()
            .eventIdEqualTo(event.id)
            .findFirst();
        if (existing != null) {
          // Own messages are inserted optimistically without the raw signed
          // event. Backfill it from the relay echo so mesh negentropy can
          // advertise + forward them.
          if (existing.rawEventJson == null && model.rawEventJson != null) {
            existing.rawEventJson = model.rawEventJson;
            await isar.noteModels.put(existing);
          }
          return;
        }
        await isar.noteModels.put(model);

        // Unread row for messages from other users (own sends are pre-seen).
        if (event.pubkey != activePubkey) {
          await putUnreadRowInTxn(isar, model);
        }

        // Reference edges: reply target + mentions, minus the group root.
        // Unique (parentId, childId) index keeps re-delivery idempotent.
        final parents = replyEdgeParentIds(
          replyToEventId: replyEventId,
          rootEventId: groupId,
          eTagRefs: eTagRefs,
        );
        for (final parentId in parents) {
          await isar.noteRelationModels.put(
            NoteRelationModel()
              ..parentId = parentId
              ..childId = event.id
              ..createdAt = EventParser.dateTimeFromSec(event.createdAt),
          );
        }
      });
    } catch (_) {
      return;
    }
  }
}
