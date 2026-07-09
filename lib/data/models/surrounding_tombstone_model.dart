import 'package:isar_community/isar.dart';

part 'surrounding_tombstone_model.g.dart';

/// A Surrounding-feed note the user removed from their own view. Local-only and
/// short-lived: it suppresses re-storage of the same event while the mesh keeps
/// re-broadcasting it, then expires with the same 1-day TTL as the ephemeral
/// [SurroundingNoteModel] cache (see `kSurroundingRetention`). After the
/// tombstone is evicted the note may reappear if still broadcast — acceptable
/// for an ephemeral surface.
///
/// Distinct from [DeletedNoteModel]: that one is permanent, synced across the
/// user's own devices, and suppresses notes from the main `Note` store. This
/// one never leaves the device and only gates `SurroundingNoteModel`. Like the
/// daily cache eviction, this is a local suppression record — not a `deleted`
/// field and not NIP-09, so it honors Feed Freedom.
@Collection(ignore: {'copyWith'})
@Name('SurroundingTombstone')
class SurroundingTombstoneModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String eventId;

  /// When the user removed the note — drives the 1-day TTL eviction.
  @Index()
  late DateTime deletedAt;
}
