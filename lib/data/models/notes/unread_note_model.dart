import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/notes/note_model.dart';

part 'unread_note_model.g.dart';

/// One row per UNREAD message. Presence of a row = the message is unread;
/// deleting the row = the message has been read. This replaces the old
/// `NoteModel.isSeen` boolean.
///
/// Denormalized projection of the fields the feed + drawer need so that the
/// feed queue/banner queries and the per-container drawer counts are single
/// indexed lookups. `NoteModel` is immutable once written, so these fields
/// never need to be re-synced after insert.
@Collection(ignore: {'copyWith'})
@Name('UnreadNote')
class UnreadNoteModel {
  Id id = Isar.autoIncrement;

  /// Idempotent: re-delivery of the same event just replaces the row.
  @Index(unique: true, replace: true)
  late String eventId;

  /// Nostr kind — 1 (feed) / 42 (group) / 14|15 (DM) / 9023 (private group).
  @Index()
  late int kind;

  /// Used to re-apply the kind-1 feed author allow-list (own + followed) at
  /// query time.
  @Index()
  late String authorPubkey;

  /// NIP-28 group root id. Non-null only for kind 42. (drawer count)
  @Name('channelId') // stored name preserved across channel→group rename
  @Index()
  String? groupId;

  /// NIP-29 group id. Non-null only for kind 9023. (drawer count)
  @Name('groupId') // stored name preserved (was UnreadNoteModel.groupId)
  @Index()
  String? privateGroupId;

  /// DM conversation FK. Non-null only for kind 14/15. (drawer count)
  @Index()
  int? conversationId;

  /// Feed `loadedAt` bucket split + cursor pagination.
  @Index()
  late DateTime created;
}

/// Inserts an unread row for [m] within an existing `writeTxn`. Idempotent —
/// the unique `eventId` index replaces any prior row. Call only for NEW,
/// non-own inbound messages.
Future<void> putUnreadRowInTxn(Isar isar, NoteModel m) {
  return isar.unreadNoteModels.put(
    UnreadNoteModel()
      ..eventId = m.eventId
      ..kind = m.kind
      ..authorPubkey = m.authorPubkey
      ..groupId = m.groupId
      ..privateGroupId = m.privateGroupId
      ..conversationId = m.conversationId
      ..created = m.created,
  );
}
