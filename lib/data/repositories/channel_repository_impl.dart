import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/repositories/channel_repository.dart';

@Injectable(as: ChannelRepository)
class ChannelRepositoryImpl extends ChannelRepository {
  final Isar isar;

  ChannelRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, ChannelEntity>> saveChannel(
    ChannelEntity channel,
  ) async {
    try {
      final existing = await isar.channelModels
          .where()
          .channelIdEqualTo(channel.channelId)
          .findFirst();

      final model = existing ?? ChannelModel();
      model.channelId = channel.channelId;
      model.creatorPubKey = channel.creatorPubKey;
      model.name = channel.name;
      model.about = channel.about;
      model.picture = channel.picture;
      model.relays = List<String>.from(channel.relays);
      model.createdAt = channel.createdAt;
      model.updatedAt = channel.updatedAt;
      model.lastMetaEvent = channel.lastMetaEvent;
      await isar.writeTxn(() async {
        await isar.channelModels.put(model);
      });

      return Right(model.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChannelEntity>> updateChannelMetadata(
    String channelId,
    String metaEventId,
    int metaEventCreatedAt,
    String name,
    String about,
    String picture,
  ) async {
    try {
      final existing = await isar.channelModels
          .where()
          .channelIdEqualTo(channelId)
          .findFirst();
      if (existing == null) {
        return Left(
          Failure.notFoundFailure('Channel not found for id: $channelId'),
        );
      }

      // Guard against out-of-order metadata events from relays.
      if (metaEventCreatedAt <= existing.updatedAt) {
        return Right(existing.toDomain());
      }

      await isar.writeTxn(() async {
        existing.name = name;
        existing.about = about;
        existing.picture = picture;
        existing.updatedAt = metaEventCreatedAt;
        existing.lastMetaEvent = metaEventId;
        await isar.channelModels.put(existing);
      });

      return Right(existing.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChannelEntity>>> getChannels() async {
    try {
      final rows = await isar.channelModels.where().findAll();
      return Right(rows.map((c) => c.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChannelEntity>> getChannelById(
    String channelId,
  ) async {
    try {
      final channel = await isar.channelModels
          .where()
          .channelIdEqualTo(channelId)
          .findFirst();
      if (channel == null) {
        return Left(
          Failure.notFoundFailure('Channel not found for id: $channelId'),
        );
      }
      return Right(channel.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
