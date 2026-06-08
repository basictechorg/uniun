import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/domain/entities/relay/relay_entity.dart';
import 'package:uniun/domain/repositories/relay_repository.dart';

@Injectable(as: RelayRepository)
class RelayRepositoryImpl extends RelayRepository {
  final Isar isar;

  RelayRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, List<RelayEntity>>> getAll() async {
    try {
      final rows = await isar.relayModels.where().findAll();
      return Right(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, RelayEntity>> save(RelayEntity relay) async {
    try {
      await isar.writeTxn(() async {
        final existing = await isar.relayModels
            .where()
            .urlEqualTo(relay.url)
            .findFirst();

        if (existing != null) {
          existing
            ..read = relay.read
            ..write = relay.write;
          await isar.relayModels.put(existing);
        } else {
          final model = RelayModel()
            ..url = relay.url
            ..read = relay.read
            ..write = relay.write
            ..status = RelayStatus.disconnected
            ..lastConnectedAt = null
            ..isSystem = relay.isSystem;
          await isar.relayModels.put(model);
        }
      });

      final saved = await isar.relayModels
          .where()
          .urlEqualTo(relay.url)
          .findFirst();
      return Right(saved!.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(String url) async {
    try {
      await isar.writeTxn(() async {
        final existing = await isar.relayModels
            .where()
            .urlEqualTo(url)
            .findFirst();
        if (existing == null) return;
        if (existing.isSystem) {
          throw Exception('System relays cannot be deleted.');
        }
        await isar.relayModels.delete(existing.id);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  static const _kSystemRelayUrls = <String>{AppConstants.kUniunBackend};

  @override
  Future<void> insertDefaultRelayIfEmpty() async {
    await isar.writeTxn(() async {
      for (final url in _kSystemRelayUrls) {
        final existing =
            await isar.relayModels.where().urlEqualTo(url).findFirst();
        if (existing != null && !existing.isSystem) {
          await isar.relayModels.delete(existing.id);
        }
        final stillThere =
            await isar.relayModels.where().urlEqualTo(url).findFirst();
        if (stillThere != null) continue;
        await isar.relayModels.put(
          RelayModel()
            ..url = url
            ..read = true
            ..write = true
            ..status = RelayStatus.disconnected
            ..isSystem = true,
        );
      }
    });
  }
}
