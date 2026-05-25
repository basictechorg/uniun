import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Shared utilities for building and signing Nostr events in the Brahma module.
/// Used by BrahmaCreateBloc for both new notes and draft publishing.

/// Extracts `#hashtag` words from [content] as a de-duplicated list.
List<String> extractHashtags(String content) {
  final matches = RegExp(r'#(\w+)').allMatches(content);
  return matches
      .map((m) => m.group(1)!)
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();
}

/// Builds the NIP-10 tag list for a note.
///
/// [mentionIds] should be the e-tag event IDs of referenced notes.
List<List<String>> buildNoteTags({
  String? rootEventId,
  String? replyToEventId,
  required List<String> mentionIds,
  required List<String> hashtags,
}) {
  return [
    if (rootEventId != null) ['e', rootEventId, '', 'root'],
    if (replyToEventId != null) ['e', replyToEventId, '', 'reply'],
    for (final id in mentionIds) ['e', id, '', 'mention'],
    for (final h in hashtags) ['t', h],
  ];
}

/// Signs [content] with [privkeyHex] and returns the resulting Nostr [Event].
/// Throws if signing fails.
Event signNostrEvent({
  required String content,
  required List<List<String>> tags,
  required String privkeyHex,
}) {
  return Event.from(
    kind: 1,
    tags: tags,
    content: content,
    privkey: privkeyHex,
  );
}

/// Converts a signed [Event] into a domain [NoteEntity].
NoteEntity noteEntityFromEvent({
  required Event event,
  required String pubkeyHex,
  required List<String> eTagRefs,
  required List<String> tTags,
  String? rootEventId,
  String? replyToEventId,
}) {
  return NoteEntity(
    id: event.id,
    sig: event.sig,
    authorPubkey: pubkeyHex,
    content: event.content,
    type: NoteType.text,
    eTagRefs: eTagRefs,
    pTagRefs: const [],
    tTags: tTags,
    created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    isSeen: true,
    rootEventId: rootEventId,
    replyToEventId: replyToEventId,
  );
}
