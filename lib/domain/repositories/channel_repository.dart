import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';

abstract class ChannelRepository {
  Future<Either<Failure, ChannelEntity>> saveChannel(ChannelEntity channel);

  Future<Either<Failure, ChannelEntity>> updateChannelMetadata(
    String channelId,
    String metaEventId,
    int metaEventCreatedAt,
    String name,
    String about,
    String picture,
  );

  Future<Either<Failure, List<ChannelEntity>>> getChannels();

  Future<Either<Failure, ChannelEntity>> getChannelById(String channelId);
}
