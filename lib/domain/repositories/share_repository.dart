import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';

/// Shares an existing note into another surface (feed / channel / DM / private
/// channel) by publishing a new event in the target surface. The original is
/// carried **by value** as a self-contained snapshot in an `embeddedNoteJson`
/// tag (see `EmbeddedNoteCodec`) — the receiver renders it without an Isar
/// lookup, immune to retention. The user's own composed note (text +
/// references + images) rides alongside as a normal note. Encrypted
/// destinations carry the snapshot inside the encrypted payload.
///
/// The repository never bypasses the existing publish flows; it dispatches
/// to the kind-specific use case for the chosen [ShareDestination].
abstract class ShareRepository {
  Future<Either<Failure, Unit>> shareNote(ShareNoteInput input);
}
