import 'dart:convert';

import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Single source of truth for embed-by-value sharing.
///
/// A shared note carries the ORIGINAL event as a self-contained JSON snapshot
/// `{id, pubkey, created_at, kind, tags, content, sig}` — on feed / channel / DM
/// it travels in a `["embeddedNoteJson", <json>]` tag; on private channels it
/// travels in the MLS envelope under key `"b"`. The receiver renders the embed
/// straight from the snapshot — no Isar lookup, immune to retention.
class EmbeddedNoteCodec {
  EmbeddedNoteCodec._();

  /// Wire tag name (feed / channel / DM). The private-channel MLS envelope uses
  /// the key `"b"` for the same string.
  static const String tagName = 'embeddedNoteJson';

  /// Rebuilds the source event's wire form from a resolved [note], reusing the
  /// original `id`/`sig`/`pubkey`/`created_at` — never re-signed. Tags are
  /// reconstructed in the app's canonical order (e root/reply/mention → p → t →
  /// imeta), mirroring [buildNoteTags] + [buildImetaTags].
  ///
  /// NOTE: [verifyAndSanitize] only passes when the rebuilt tag order matches
  /// what the original author signed. App-native notes always match; a note
  /// authored by a foreign client with a different tag order is flagged
  /// "unverified" on the receiver (safe — never the reverse).
  static Map<String, dynamic> snapshotMapFromEntity(NoteEntity note) {
    final tags = <List<String>>[
      if (note.rootEventId != null) ['e', note.rootEventId!, '', 'root'],
      if (note.replyToEventId != null) ['e', note.replyToEventId!, '', 'reply'],
      for (final ref in note.eTagRefs)
        if (ref != note.rootEventId && ref != note.replyToEventId)
          ['e', ref, '', 'mention'],
      for (final p in note.pTagRefs) ['p', p],
      for (final t in note.tTags) ['t', t],
      ...buildImetaTags(note.attachments),
    ];
    return <String, dynamic>{
      'id': note.id,
      'pubkey': note.authorPubkey,
      'created_at': note.created.millisecondsSinceEpoch ~/ 1000,
      'kind': note.kind,
      'tags': tags,
      'content': note.content,
      'sig': note.sig,
    };
  }

  /// JSON snapshot string for [note], placed in the tag / envelope.
  static String encodeFromEntity(NoteEntity note) =>
      jsonEncode(snapshotMapFromEntity(note));

  /// The Nostr tag form for feed / channel / DM surfaces.
  static List<String> tag(String snapshotJson) => [tagName, snapshotJson];

  /// Verifies the snapshot's id + Schnorr signature. On ANY failure
  /// (unparseable, id mismatch, or bad sig) the `sig` is blanked so the UI flags
  /// the embed as unverified. Returns the (possibly sig-blanked) snapshot. Run
  /// ONCE at inbound — schnorr verification is too costly per render.
  static String verifyAndSanitize(String snapshotJson) {
    Map<String, dynamic>? map;
    try {
      map = jsonDecode(snapshotJson) as Map<String, dynamic>;
      if (Event.fromJson(map, verify: false).isValid()) return snapshotJson;
    } catch (_) {
      // fall through to blanking
    }
    if (map == null) return snapshotJson;
    map['sig'] = '';
    return jsonEncode(map);
  }
}
