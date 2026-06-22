// lib/data/repositories/manthan_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/manthan_card_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/manthan/manthan_card_model.dart';
import 'package:uniun/domain/entities/manthan/manthan_card_entity.dart';
import 'package:uniun/domain/repositories/manthan_repository.dart';

@Injectable(as: ManthanRepository)
class ManthanRepositoryImpl extends ManthanRepository {
  final Isar isar;
  ManthanRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, ManthanCardEntity?>> nextBufferedCard(
      String scopeId) async {
    try {
      final row = await isar.manthanCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .statusEqualTo(ManthanCardStatus.buffered.name)
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
      final rows = await isar.manthanCardModels
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
      List<ManthanCardEntity> cards) async {
    try {
      final models = cards.map((c) {
        return ManthanCardModel()
          ..scopeId = c.scopeId
          ..signature = c.signature
          ..noteIds = c.noteIds
          ..generatedParagraph = c.generatedParagraph
          ..status = c.status.name
          ..createdAt = c.createdAt
          ..lastSeenAt = c.lastSeenAt;
      }).toList();
      await isar.writeTxn(() async {
        await isar.manthanCardModels.putAll(models);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateStatus(
      String scopeId, String signature, ManthanCardStatus status) async {
    try {
      final row = await isar.manthanCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .signatureEqualTo(signature)
          .findFirst();
      if (row == null) return const Right(unit);
      row
        ..status = status.name
        ..lastSeenAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.manthanCardModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> countByStatus(
      String scopeId, ManthanCardStatus status) async {
    try {
      final n = await isar.manthanCardModels
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
      final rows = await isar.manthanCardModels
          .filter()
          .scopeIdEqualTo(scopeId)
          .statusEqualTo(ManthanCardStatus.discarded.name)
          .sortByLastSeenAt() // nulls sort first → oldest revisited first
          .limit(limit)
          .findAll();
      if (rows.isEmpty) return const Right(0);
      for (final r in rows) {
        r.status = ManthanCardStatus.buffered.name;
      }
      await isar.writeTxn(() async {
        await isar.manthanCardModels.putAll(rows);
      });
      return Right(rows.length);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
