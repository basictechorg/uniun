import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Which Isar collection a resolved note came from. Determines the transport a
/// reply must be posted through.
enum NoteSource { feed, channel, privateChannel, dm }

/// A note resolved from *any* collection, carrying the routing info a reply
/// needs (the read side is uniform `NoteEntity`; only the write transport
/// differs per source).
class ResolvedNote {
  const ResolvedNote({
    required this.note,
    required this.source,
    this.channelId,
    this.groupId,
    this.dmReceiverPubkey,
  });

  final NoteEntity note;
  final NoteSource source;

  /// NIP-28 channel id (when [source] is [NoteSource.channel]).
  final String? channelId;

  /// NIP-29 group id (when [source] is [NoteSource.privateChannel]).
  final String? groupId;

  /// The receiver pubkey stored on the DM (when [source] is [NoteSource.dm]).
  /// The reply counterparty is derived from this + the message author at send.
  final String? dmReceiverPubkey;
}

/// Finds notes/messages across every collection by their globally-unique event
/// id. This is what lets one thread screen render a note regardless of which
/// surface (feed / channel / private channel / DM) produced it, and lets a note
/// reference a message stored in a different collection.
abstract class NoteResolverRepository {
  /// Resolves [id] from whichever collection holds it (first hit wins), with
  /// its source + routing info. `notFoundFailure` when no collection has it.
  Future<Either<Failure, ResolvedNote>> resolveById(String id);

  /// Lightweight lookup returning just the [NoteEntity] (parent / mentions).
  /// Returns `null` (as `Right(null)`) when not found anywhere.
  Future<Either<Failure, NoteEntity?>> resolveNoteById(String id);

  /// Direct replies to [id] — `replyToEventId == id` across all collections,
  /// merged, de-duplicated and sorted oldest→newest.
  Future<Either<Failure, List<NoteEntity>>> resolveReplies(String id);

  /// Resolves each id in [ids], skipping any that aren't found.
  Future<Either<Failure, List<NoteEntity>>> resolveMany(List<String> ids);
}
