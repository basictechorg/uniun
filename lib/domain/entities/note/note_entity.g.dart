// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NoteEntity _$NoteEntityFromJson(Map<String, dynamic> json) => _NoteEntity(
  id: json['id'] as String,
  sig: json['sig'] as String,
  authorPubkey: json['authorPubkey'] as String,
  content: json['content'] as String,
  subject: json['subject'] as String?,
  kind: (json['kind'] as num?)?.toInt() ?? 1,
  type: $enumDecode(_$NoteTypeEnumMap, json['type']),
  eTagRefs: (json['eTagRefs'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  pTagRefs: (json['pTagRefs'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  tTags: (json['tTags'] as List<dynamic>).map((e) => e as String).toList(),
  created: DateTime.parse(json['created'] as String),
  conversationId: (json['conversationId'] as num?)?.toInt(),
  rootEventId: json['rootEventId'] as String?,
  replyToEventId: json['replyToEventId'] as String?,
  cachedReplyCount: (json['cachedReplyCount'] as num?)?.toInt() ?? 0,
  referenceCount: (json['referenceCount'] as num?)?.toInt() ?? 0,
  sourceChannelId: json['sourceChannelId'] as String?,
  sourcePrivateGroupId: json['sourcePrivateGroupId'] as String?,
  sourceLabel: json['sourceLabel'] as String?,
);

Map<String, dynamic> _$NoteEntityToJson(_NoteEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sig': instance.sig,
      'authorPubkey': instance.authorPubkey,
      'content': instance.content,
      'subject': instance.subject,
      'kind': instance.kind,
      'type': _$NoteTypeEnumMap[instance.type]!,
      'eTagRefs': instance.eTagRefs,
      'pTagRefs': instance.pTagRefs,
      'tTags': instance.tTags,
      'created': instance.created.toIso8601String(),
      'conversationId': instance.conversationId,
      'rootEventId': instance.rootEventId,
      'replyToEventId': instance.replyToEventId,
      'cachedReplyCount': instance.cachedReplyCount,
      'referenceCount': instance.referenceCount,
      'sourceChannelId': instance.sourceChannelId,
      'sourcePrivateGroupId': instance.sourcePrivateGroupId,
      'sourceLabel': instance.sourceLabel,
    };

const _$NoteTypeEnumMap = {
  NoteType.text: 'text',
  NoteType.image: 'image',
  NoteType.link: 'link',
  NoteType.reference: 'reference',
};
