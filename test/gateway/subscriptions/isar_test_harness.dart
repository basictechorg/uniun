import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/datasources/isar_schemas.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';

int _isarSeq = 0;

/// Opens an isolated on-disk Isar (unique name + temp dir) registered with the
/// app's full schema list. Caller must `close(deleteFromDisk: true)` in tearDown.
Future<Isar> openTestIsar() async {
  await Isar.initializeIsarCore(download: true);
  final dir = await Directory.systemTemp.createTemp('uniun_sub_test');
  return Isar.open(isarSchemas, directory: dir.path, name: 'sub_test_${_isarSeq++}');
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
