/// Resolves the display *name* of a public channel or private group given
/// its id. The caller (NoteCard) picks the appropriate icon based on which
/// of [NoteEntity.sourceChannelId] / [sourcePrivateGroupId] is set, so the
/// repo deliberately returns just the name with no `#` / 🔒 decoration.
///
/// Backed by a batched Isar lookup — exactly two queries regardless of how
/// many items are passed in, so it stays cheap even with thousands of
/// saved notes on the list.
abstract class SourceLabelRepository {
  /// Returns a map keyed by `eventId` containing the channel or group name.
  /// Items with no source id (native Kind-1 notes) emit no entry; items
  /// whose source row isn't in local Isar fall back to `"channel"` /
  /// `"private"`.
  Future<Map<String, String>> resolveMany(
    Iterable<({String eventId, String? channelId, String? groupId})> items,
  );
}
