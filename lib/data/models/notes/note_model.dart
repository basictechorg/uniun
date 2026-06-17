import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/notes/imeta_parser.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_dim.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

part 'note_model.g.dart';

/// Unified note collection. Every user-visible message lives here, discriminated
/// by Nostr [kind] plus nullable container fields:
///   - [kind] == 1     → feed note (no container)
///   - [kind] == 42    → public channel message ([channelId] set)
///   - [kind] == 14/15 → direct message ([conversationId] set)
///   - [kind] == 9023  → private channel message ([groupId] set)
/// See [note_kinds.dart] for the kind constants.
@Collection(ignore: {'copyWith'})
@Name('Note')
class NoteModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  late String sig;

  /// Indexed for fast `authorPubkey in [followedList]` feed queries.
  @Index()
  late String authorPubkey;
  late String content;
  String? subject;

  /// Nostr event kind — the discriminator for the unified collection.
  /// 1 = feed note, 42 = channel message, 14/15 = DM, 9023 = private channel.
  @Index()
  late int kind;

  /// NIP-28 channel root (kind 40 event id). Non-null only for [kind] == 42.
  @Index()
  String? channelId;

  /// NIP-29 group id (`<host>'<group-id>`). Non-null only for [kind] == 9023.
  @Index()
  String? groupId;

  /// DM conversation FK (DmConversationModel.id). Non-null only for DMs.
  @Index()
  int? conversationId;

  @Enumerated(EnumType.name)
  late NoteType type;

  late List<String> eTagRefs;

  /// NIP-10: event ID of the thread root (["e", id, relay, "root"])
  /// null = this note IS the root (top-level feed note)
  @Index()
  String? rootEventId;

  /// NIP-10: event ID of the direct parent (["e", id, relay, "reply"])
  /// null = top-level note
  @Index()
  String? replyToEventId;

  late List<String> pTagRefs;
  late List<String> tTags;

  @Index()
  late DateTime created;

  /// Embed-by-value snapshot of the quoted original (the `embeddedNoteJson`
  /// tag / MLS envelope key). Persisted already sig-verified — a blanked `sig`
  /// inside means the embed failed verification. Source of truth for the
  /// resolved `quotedNote`; null when this note quotes nothing.
  String? embeddedNoteJson;

  /// True when [attachments] is non-empty. Stored (instead of derived) so
  /// the index lets feed queries cheaply skip text-only notes when needed.
  /// Set automatically by the constructor + the inbound parser.
  @Index()
  late bool hasMedia = false;

  /// NIP-92 `imeta` attachments. One entry per attached blob. Bytes live on
  /// disk only when [MediaCacheModel] has a row for the same SHA — this list
  /// describes the files, not the cached state.
  List<MediaAttachment> attachments = const [];

  NoteModel({
    required this.eventId,
    required this.sig,
    required this.authorPubkey,
    required this.content,
    this.subject,
    this.kind = kNoteKind,
    this.channelId,
    this.groupId,
    this.conversationId,
    required this.type,
    required this.eTagRefs,
    this.rootEventId,
    this.replyToEventId,
    required this.pTagRefs,
    required this.tTags,
    required this.created,
    this.embeddedNoteJson,
    List<MediaAttachment> attachments = const [],
  })  : attachments = attachments,
        hasMedia = attachments.isNotEmpty;

  /// Parse a Kind 1 Nostr event (from the Dart Gateway / EmbeddedServer) into a NoteModel.
  ///
  /// NIP-10 threading rules applied here:
  ///   - e-tag with marker "root"  → rootEventId
  ///   - e-tag with marker "reply" → replyToEventId
  ///   - all e-tag ids (including root/reply/mention) → eTagRefs
  factory NoteModel.fromEvent(Event event) {
    final eTagRefs = <String>[];
    String? rootEventId;
    String? replyToEventId;
    String? subject;
    final pTagRefs = <String>[];
    final tTags = <String>[];
    String? embeddedNoteJson;

    for (final tag in event.tags) {
      if (tag.isEmpty) continue;
      final tagName = tag[0];
      if (tagName == 'e' && tag.length >= 2) {
        final eventId = tag[1];
        eTagRefs.add(eventId);
        if (tag.length >= 4) {
          final marker = tag[3];
          if (marker == 'root') rootEventId = eventId;
          if (marker == 'reply') replyToEventId = eventId;
        }
      } else if (tagName == EmbeddedNoteCodec.tagName && tag.length >= 2) {
        // Embed-by-value share — verify the snapshot once, here at the edge.
        embeddedNoteJson = EmbeddedNoteCodec.verifyAndSanitize(tag[1]);
      } else if (tagName == 'p' && tag.length >= 2) {
        pTagRefs.add(tag[1]);
      } else if (tagName == 't' && tag.length >= 2) {
        tTags.add(tag[1]);
      } else if (tagName == 'subject' && tag.length >= 2) {
        subject = tag[1];
      }
    }

    // Infer NoteType from content/tags
    NoteType type = NoteType.text;
    if (eTagRefs.isNotEmpty && event.content.isEmpty) {
      type = NoteType.reference;
    } else if (event.content.startsWith('http') &&
        (event.content.contains('.jpg') ||
            event.content.contains('.jpeg') ||
            event.content.contains('.png') ||
            event.content.contains('.gif') ||
            event.content.contains('.webp'))) {
      type = NoteType.image;
    } else if (event.content.startsWith('http')) {
      type = NoteType.link;
    }

    return NoteModel(
      eventId: event.id,
      sig: event.sig,
      authorPubkey: event.pubkey,
      content: event.content,
      subject: subject,
      kind: event.kind,
      type: type,
      eTagRefs: eTagRefs,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      pTagRefs: pTagRefs,
      tTags: tTags,
      created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      embeddedNoteJson: embeddedNoteJson,
      attachments: ImetaParser.parseAsAttachments({'tags': event.tags}),
    );
  }
}

extension NoteModelExtension on NoteModel {
  /// Builds the domain entity. `attachments` are converted to
  /// [MediaBlobEntity] with `localPath` / `downloadedAt` left null —
  /// `NoteAttachmentsEnricher` fills those by joining [MediaCacheModel] in a
  /// bulk pass. Same shape the UI already expects.
  ///
  /// When [embeddedNoteJson] is set, the embedded original is decoded straight
  /// from the snapshot (no Isar lookup, retention-immune) and attached as
  /// `quotedNote` — exactly one level deep (`quotedNote.quotedNote == null`).
  NoteEntity toDomain() => _toDomain(resolveQuote: true);

  NoteEntity _toDomain({required bool resolveQuote}) => NoteEntity(
        id: eventId,
        sig: sig,
        authorPubkey: authorPubkey,
        content: content,
        subject: subject,
        kind: kind,
        type: type,
        eTagRefs: eTagRefs,
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        pTagRefs: pTagRefs,
        tTags: tTags,
        created: created,
        conversationId: conversationId,
        sourceChannelId: channelId,
        sourcePrivateGroupId: groupId,
        embeddedNoteJson: embeddedNoteJson,
        quotedNote: resolveQuote ? _buildQuotedNote() : null,
        attachments: [for (final a in attachments) a.toEntity()],
      );

  /// Decodes [embeddedNoteJson] into the quoted note (one level deep).
  NoteEntity? _buildQuotedNote() => decodeEmbeddedNote(embeddedNoteJson);
}

/// Decodes an embed-by-value snapshot string into its quoted note entity,
/// exactly one level deep (`quotedNote.quotedNote == null`). Returns null when
/// [snapshot] is null or unparseable. Shared by [NoteModel] and
/// [SavedNoteModel] `toDomain()`.
NoteEntity? decodeEmbeddedNote(String? snapshot) {
  if (snapshot == null) return null;
  try {
    final event = Event.fromJson(
        jsonDecode(snapshot) as Map<String, dynamic>,
        verify: false);
    return NoteModel.fromEvent(event)._toDomain(resolveQuote: false);
  } catch (_) {
    return null;
  }
}

extension MediaAttachmentMapper on MediaAttachment {
  /// Embedded row → domain entity. Cache state stays null here; the
  /// enricher patches it in a single bulk read.
  MediaBlobEntity toEntity() => MediaBlobEntity(
        sha256: sha256,
        mime: mime,
        sizeBytes: sizeBytes,
        dim: (width != null && height != null)
            ? MediaDim(width: width!, height: height!)
            : null,
        blurhash: blurhash,
        filename: filename,
        serverUrls: url != null ? [url!] : const [],
        localPath: null,
        downloadedAt: null,
      );
}
