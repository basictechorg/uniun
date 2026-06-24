import 'dart:io';
import 'dart:math' as math;

import 'package:isar_community/isar.dart';
import 'package:uniun/data/datasources/isar_schemas.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';

final math.Random _rng = math.Random();

/// Opens an isolated on-disk Isar registered with the app's full schema list.
///
/// The instance name is salted with the current microsecond timestamp plus a
/// random suffix so parallel tests (and re-runs after a flaky teardown) never
/// share a name with a still-finalizing Isar — previously a single integer
/// counter was reused across runs, which segfaulted Isar's native finalizer
/// when a slow `deleteFromDisk` overlapped a fresh open at the same name.
///
/// Caller must `close(deleteFromDisk: true)` in `tearDown`.
Future<Isar> openTestIsar() async {
  await Isar.initializeIsarCore(download: true);
  final dir = await Directory.systemTemp.createTemp('uniun_sub_test');
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final salt = _rng.nextInt(1 << 32).toRadixString(16);
  return Isar.open(
    isarSchemas,
    directory: dir.path,
    name: 'sub_test_${stamp}_$salt',
  );
}

ChannelModel channelSeed(String channelId) => ChannelModel()
  ..channelId = channelId
  ..creatorPubKey = 'creator'
  ..name = 'name'
  ..about = 'about'
  ..picture = ''
  ..relays = const []
  ..createdAt = 0
  ..updatedAt = 0;

PrivateChannelModel privateChannelSeed(String groupId) => PrivateChannelModel()
  ..groupId = groupId
  ..mlsGroupId = 'mls_$groupId'
  ..relays = const []
  ..name = 'name'
  ..description = 'desc'
  ..adminPubkey = 'admin';

FollowedUserModel followedUserSeed(String pubkeyHex) => FollowedUserModel()
  ..pubkeyHex = pubkeyHex
  ..followedAt = DateTime(2026, 1, 1);

FollowedNoteModel followedNoteSeed(String eventId) => FollowedNoteModel()
  ..eventId = eventId
  ..contentPreview = 'preview'
  ..followedAt = DateTime(2026, 1, 1)
  ..newReferenceCount = 0;
