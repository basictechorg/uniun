import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';

part 'channel_message_model.g.dart';

/// Persisted NIP-28 kind **42** channel message (same role as [NoteModel] for kind 1).
@Collection(ignore: {'copyWith'})
@Name('ChannelMessage')
class ChannelMessageModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  /// NIP-28 root id (kind **40** event id).
  @Index()
  late String channelId;

  late String sig;
  late String authorPubkey;
  late String content;

  late List<String> eTagRefs;

  @Index()
  String? rootEventId;

  @Index()
  String? replyToEventId;

  late List<String> pTagRefs;

  @Index()
  late DateTime created;

  /// Composite index: (isSeen, created) — same role as NoteModel.isSeen so the
  /// unified Vishnu feed buckets are indexed scans on this collection too.
  @Index(composite: [CompositeIndex('created')])
  late bool isSeen = false;
}

extension ChannelMessageModelExtension on ChannelMessageModel {
  ChannelMessageEntity toDomain() => ChannelMessageEntity(
        id: eventId,
        channelId: channelId,
        sig: sig,
        authorPubkey: authorPubkey,
        content: content,
        eTagRefs: List<String>.from(eTagRefs),
        pTagRefs: List<String>.from(pTagRefs),
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        created: created,
        isSeen: isSeen,
      );
}
