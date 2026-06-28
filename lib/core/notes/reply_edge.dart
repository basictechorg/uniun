/// Parent event IDs a note or group message references for reply-count
/// edges: the direct reply target plus pure mentions, excluding the thread
/// root marker so nested thread replies don't inflate the root's count.
///
/// Pure (no Isar) so it is shared by data-layer repositories and the
/// gateway-isolate inbound handlers — keeping the NIP-10 rule in one place.
Set<String> replyEdgeParentIds({
  required String? replyToEventId,
  required String? rootEventId,
  required List<String> eTagRefs,
}) {
  final parents = <String>{};
  if (replyToEventId != null) parents.add(replyToEventId);
  for (final ref in eTagRefs) {
    if (ref != rootEventId && ref != replyToEventId) parents.add(ref);
  }
  return parents;
}
