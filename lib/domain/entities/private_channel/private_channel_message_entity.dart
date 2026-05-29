import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

class PrivateChannelMessageEntity implements NoteEntity {
  final String eventId;
  final String groupId;
  final String senderPubkey;
  final String decryptedContent;
  final DateTime timestamp;

  const PrivateChannelMessageEntity({
    required this.eventId,
    required this.groupId,
    required this.senderPubkey,
    required this.decryptedContent,
    required this.timestamp,
  });

  @override
  String get id => eventId;
  @override
  String get authorPubkey => senderPubkey;
  @override
  String get content => decryptedContent;
  @override
  DateTime get created => timestamp;

  @override
  String get sig => '';
  @override
  String? get subject => null;
  @override
  NoteType get type => NoteType.text;
  @override
  List<String> get eTagRefs => const [];
  @override
  List<String> get pTagRefs => const [];
  @override
  List<String> get tTags => const [];
  @override
  bool get isSeen => true;
  @override
  String? get rootEventId => null;
  @override
  String? get replyToEventId => null;
  @override
  int get cachedReplyCount => 0;

  @override
  $NoteEntityCopyWith<NoteEntity> get copyWith =>
      throw UnimplementedError('copyWith not supported on PrivateChannelMessageEntity');

  @override
  Map<String, dynamic> toJson() =>
      throw UnimplementedError('toJson not supported on PrivateChannelMessageEntity');
}
