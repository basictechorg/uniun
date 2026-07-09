import 'package:isar_community/isar.dart';

part 'followed_note_model.g.dart';

/// A note the local user has subscribed to for graph updates.
///
/// The unread badge count is NOT stored here — it is derived at read time
/// as `NoteRelationModel rows where parentId == eventId` intersected with
/// live `UnreadNoteModel` rows (`childId ∈ unreadNoteModels.eventId`).
/// Reading a referencing note deletes its unread row; the badge drops
/// automatically. Idempotent by construction — no counter to drift.
@Collection(ignore: {'copyWith'})
@Name('FollowedNote')
class FollowedNoteModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  late String contentPreview;
  late DateTime followedAt;

  /// Signed+encrypted Nostr Kind 30501 event for this row (§3). Nullable
  /// during Phase 0a migration.
  String? signedNostrEvent;

  /// Tombstone marker (§5a). Null on active follows.
  @Index()
  DateTime? removedAt;
}
