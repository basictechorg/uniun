// lib/data/repositories/nataraj_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/nataraj_card_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/nataraj/nataraj_card_model.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';
import 'package:uniun/domain/repositories/nataraj_repository.dart';

@Injectable(as: NatarajRepository)
class NatarajRepositoryImpl extends NatarajRepository {
  final Isar isar;
  NatarajRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, NatarajCardEntity?>> nextBufferedCard(
      String scopeId) async {
    try {
      final row = await isar.natarajCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .statusEqualTo(NatarajCardStatus.buffered.name)
          .sortByCreatedAt()
          .findFirst();
      return Right(row?.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getKnownSignatures(
      String scopeId) async {
    try {
      final rows = await isar.natarajCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .findAll();
      return Right(rows.map((r) => r.signature).toSet());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> insertBufferedCards(
      List<NatarajCardEntity> cards) async {
    try {
      final models = cards.map((c) {
        return NatarajCardModel()
          ..scopeId = c.scopeId
          ..signature = c.signature
          ..noteIds = c.noteIds
          ..generatedParagraph = c.generatedParagraph
          ..status = c.status.name
          ..createdAt = c.createdAt
          ..lastSeenAt = c.lastSeenAt;
      }).toList();
      await isar.writeTxn(() async {
        await isar.natarajCardModels.putAll(models);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateStatus(
      String scopeId, String signature, NatarajCardStatus status) async {
    try {
      final row = await isar.natarajCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .signatureEqualTo(signature)
          .findFirst();
      if (row == null) return const Right(unit);
      row
        ..status = status.name
        ..lastSeenAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.natarajCardModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> countByStatus(
      String scopeId, NatarajCardStatus status) async {
    try {
      final n = await isar.natarajCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .statusEqualTo(status.name)
          .count();
      return Right(n);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> rehydrateOldestDiscarded(
      String scopeId, int limit) async {
    try {
      final rows = await isar.natarajCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .statusEqualTo(NatarajCardStatus.discarded.name)
          .sortByLastSeenAt() // nulls sort first → oldest revisited first
          .limit(limit)
          .findAll();
      if (rows.isEmpty) return const Right(0);
      for (final r in rows) {
        r.status = NatarajCardStatus.buffered.name;
      }
      await isar.writeTxn(() async {
        await isar.natarajCardModels.putAll(rows);
      });
      return Right(rows.length);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
