import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';

/// Shares an existing note into another surface (feed / channel / DM / private
/// channel) by publishing a new event in the target surface whose `content`
/// embeds a `nostr:note1...` pointer to the original. Receivers resolve the
/// pointer locally — encrypted originals stay opaque to non-members.
///
/// The repository never bypasses the existing publish flows; it dispatches
/// to the kind-specific use case for the chosen [ShareDestination].
abstract class ShareRepository {
  Future<Either<Failure, Unit>> shareNote(ShareNoteInput input);
}
