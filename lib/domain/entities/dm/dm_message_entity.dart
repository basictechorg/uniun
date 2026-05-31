import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

class DmMessageEntity implements NoteEntity {
  final String eventId;
  @override
  final String sig;
  @override
  final String authorPubkey;
  final int conversationId;
  final String receiverPubkey;
  @override
  final String? rootEventId;
  @override
  final String? replyToEventId;
  @override
  final List<String> eTagRefs;
  @override
  final String content;
  @override
  final String? subject;
  final int kind;
  @override
  final NoteType type;
  @override
  final DateTime created;
  @override
  final bool isSeen;

  const DmMessageEntity({
    required this.eventId,
    required this.sig,
    required this.authorPubkey,
    required this.conversationId,
    required this.receiverPubkey,
    this.rootEventId,
    this.replyToEventId,
    this.eTagRefs = const [],
    required this.content,
    this.subject,
    required this.kind,
    required this.type,
    required this.created,
    required this.isSeen,
  });

  @override
  String get id => eventId;

  @override
  List<String> get pTagRefs => [receiverPubkey];

  @override
  List<String> get tTags => const [];

  @override
  int get cachedReplyCount => 0;

  @override
  $NoteEntityCopyWith<NoteEntity> get copyWith =>
      throw UnimplementedError('copyWith not supported on DmMessageEntity');

  @override
  Map<String, dynamic> toJson() =>
      throw UnimplementedError('toJson not supported on DmMessageEntity');
}
