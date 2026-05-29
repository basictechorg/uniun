import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/domain/entities/dm/dm_message_entity.dart';
import 'package:uniun/data/models/notes/note_model.dart';

part 'dm_message_model.g.dart';

/// Stores a decrypted NIP-17 Kind 14 (and future Kind 15) direct message.
///   eventId          → eventId          (same)
///   conversationId   → conversationId   (same, resolved from pTagRefs[0] by caller)
///   pTagRef          → pTagRefs[0]      (receiver pubkey)
///   eTagRef          → replyToEventId   (NIP-17: single 'e' tag = direct parent)
///   rootEventId     = null (DMs are flat)
///   replyToEventId  = the single 'e' tag id, if present
@Collection(ignore: {'copyWith'})
@Name('DmMessage')
class DmMessageModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  late String sig;
  late String authorPubkey;

  @Index()
  late int conversationId;

  /// All 'p' tag pubkeys. 
  late List<String> pTagRefs;

  /// NIP-10 / NIP-17: event id of the message this is replying to.
  /// null = top-level message in the conversation.
  @Index()
  String? replyToEventId;


  late String content;
  String? subject;

  /// Event kind. Kind 14 = text DM. Kind 15 = file DM (not yet handled in UI,
  /// but stored so future parsing/rendering code has the information).
  late int kind;

  @Enumerated(EnumType.name)
  late NoteType type;


  late DateTime created;
  late bool isSeen;

  DmMessageModel({
    required this.eventId,
    required this.sig,
    required this.authorPubkey,
    required this.conversationId,
    required this.pTagRefs,
    this.replyToEventId,
    required this.content,
    this.subject,
    required this.kind,
    required this.type,
    required this.created,
    required this.isSeen,
  });

  /// Parse a decrypted NIP-17 Kind 14 (or Kind 15) [Event] into a [DmMessageModel].
  ///
  /// [conversationId] must be resolved by the caller (repository layer) by
  /// looking up [DmConversationModel] whose [otherPubkey] matches
  /// [pTagRefs.first].
  ///
  /// Tag parsing mirrors [NoteModel.fromEvent] so both models stay in sync:
  ///   'p'       → pTagRefs
  ///   'e'       → replyToEventId  (NIP-17: first/only 'e' tag = direct parent)
  ///   'subject' → subject
  factory DmMessageModel.fromEvent(Event event, {required int conversationId}) {
    String? replyToEventId;
    String? subject;
    final pTagRefs = <String>[];

    for (final tag in event.tags) {
      if (tag.isEmpty) continue;
      final tagName = tag[0];

      if (tagName == 'e' && tag.length >= 2) {
        // NIP-17 Kind 14: a single 'e' tag marks the direct parent — no
        // root/reply markers. We take the first one; extras are ignored.
        replyToEventId ??= tag[1];
      } else if (tagName == 'p' && tag.length >= 2) {
        pTagRefs.add(tag[1]);
      } else if (tagName == 'subject' && tag.length >= 2) {
        subject = tag[1];
      }
    }

    // NoteModel. Kind 15 file messages will be NoteType.image / .link / .text
    final type = _inferType(event.content, event.kind);

    return DmMessageModel(
      eventId: event.id,
      sig: event.sig,
      authorPubkey: event.pubkey,
      conversationId: conversationId,
      pTagRefs: pTagRefs,
      replyToEventId: replyToEventId,
      content: event.content,
      subject: subject,
      kind: event.kind,
      type: type,
      created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      isSeen: false,
    );
  }

  /// [conversationId] must be resolved by the caller before calling this.
  factory DmMessageModel.fromNote(NoteModel note, {required int conversationId}) {
    return DmMessageModel(
      eventId: note.eventId,
      sig: note.sig,
      authorPubkey: note.authorPubkey,
      conversationId: conversationId,
      // NoteModel stores all p-tags; for DMs pTagRefs[0] is always the receiver.
      pTagRefs: note.pTagRefs,
      // NIP-17 has no "root" concept for DMs — replyToEventId is enough.
      replyToEventId: note.replyToEventId,
      content: note.content,
      subject: note.subject,
      // NoteModel doesn't store kind — default to 14 (text DM).
      // If you later add kind to NoteModel, pass it through here.
      kind: 14,
      type: note.type,
      created: note.created,
      isSeen: note.isSeen,
    );
  }
}

// Helpers

NoteType _inferType(String content, int kind) {
  // Kind 15 = file message; treat as image/link once content URL is known.
  if (kind == 15) {
    return _inferTypeFromUrl(content);
  }
  // Kind 14 = plain text DM (may still contain an image URL pasted inline).
  return _inferTypeFromUrl(content);
}

NoteType _inferTypeFromUrl(String content) {
  if (content.startsWith('http')) {
    final lower = content.toLowerCase();
    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp')) {
      return NoteType.image;
    }
    return NoteType.link;
  }
  return NoteType.text;
}


extension DmMessageModelExtension on DmMessageModel {
  DmMessageEntity toDomain() => DmMessageEntity(
    eventId: eventId,
    sig: sig,
    authorPubkey: authorPubkey,
    conversationId: conversationId,
    receiverPubkey: pTagRefs.isNotEmpty ? pTagRefs.first : '',
    replyToEventId: replyToEventId,
    content: content,
    subject: subject,
    kind: kind,
    type: type,
    created: created,
    isSeen: isSeen,
  );
}