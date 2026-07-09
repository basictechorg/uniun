/// Rebuilds a signed Nostr event JSON from a note's decomposed fields, in the
/// canonical tag order used by `EventQueueModel.toSerializedRelayMessage`
/// (e:root → e:reply → e:mention → p → t → embeddedNoteJson). For our OWN
/// notes (signed in this order) the recomputed id matches, so the receiver's
/// signature check passes. Notes signed by other clients in a different order
/// won't verify and are dropped by the receiver — safe, just not propagated.
///
/// [embeddedNoteJson] carries the by-value snapshot of a quoted original (see
/// `EmbeddedNoteCodec`); replaces the legacy `q` pointer tag.
Map<String, dynamic> buildBroadcastEvent({
  required String eventId,
  required String sig,
  required String authorPubkey,
  required String content,
  required DateTime created,
  required int kind,
  required List<String> eTagRefs,
  required List<String> pTagRefs,
  required List<String> tTags,
  String? rootEventId,
  String? replyToEventId,
  String? embeddedNoteJson,
}) {
  final tags = <List<String>>[
    if (rootEventId != null) ['e', rootEventId, '', 'root'],
    if (replyToEventId != null) ['e', replyToEventId, '', 'reply'],
    for (final ref in eTagRefs)
      if (ref != rootEventId && ref != replyToEventId) ['e', ref, '', 'mention'],
    for (final p in pTagRefs) ['p', p],
    for (final t in tTags) ['t', t],
    if (embeddedNoteJson != null) ['embeddedNoteJson', embeddedNoteJson],
  ];
  return {
    'id': eventId,
    'pubkey': authorPubkey,
    'created_at': created.millisecondsSinceEpoch ~/ 1000,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': sig,
  };
}
