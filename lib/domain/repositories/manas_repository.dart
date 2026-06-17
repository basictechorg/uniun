import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';

abstract class ManasRepository {
  Future<Either<Failure, ManasEntity>> upsertManas(ManasEntity manas);
  Future<Either<Failure, List<ManasEntity>>> getManasList();
  Future<Either<Failure, ManasEntity>> getManasById(String manasId);
  Future<Either<Failure, Unit>> deleteManas(String manasId);

  /// Adds a note to a Manas. Idempotent — re-adding an existing link returns
  /// `Right(unit)` without writing.
  Future<Either<Failure, Unit>> addNoteToManas(String manasId, String noteId);

  /// Removes a note from a Manas. Idempotent — removing a non-existent link
  /// returns `Right(unit)`.
  Future<Either<Failure, Unit>> removeNoteFromManas(
      String manasId, String noteId);

  /// Note ids currently linked to this Manas, in insertion order.
  Future<Either<Failure, List<String>>> getNoteIdsForManas(String manasId);

  /// Reverse lookup — Manases this note belongs to.
  Future<Either<Failure, List<String>>> getManasIdsForNote(String noteId);
}
