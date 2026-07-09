// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNoteModelCollection on Isar {
  IsarCollection<NoteModel> get noteModels => this.collection();
}

const NoteModelSchema = CollectionSchema(
  name: r'Note',
  id: 6284318083599466921,
  properties: {
    r'attachments': PropertySchema(
      id: 0,
      name: r'attachments',
      type: IsarType.objectList,

      target: r'MediaAttachment',
    ),
    r'authorPubkey': PropertySchema(
      id: 1,
      name: r'authorPubkey',
      type: IsarType.string,
    ),
    r'channelId': PropertySchema(
      id: 2,
      name: r'channelId',
      type: IsarType.string,
    ),
    r'content': PropertySchema(id: 3, name: r'content', type: IsarType.string),
    r'conversationId': PropertySchema(
      id: 4,
      name: r'conversationId',
      type: IsarType.long,
    ),
    r'created': PropertySchema(
      id: 5,
      name: r'created',
      type: IsarType.dateTime,
    ),
    r'eTagRefs': PropertySchema(
      id: 6,
      name: r'eTagRefs',
      type: IsarType.stringList,
    ),
    r'embeddedNoteJson': PropertySchema(
      id: 7,
      name: r'embeddedNoteJson',
      type: IsarType.string,
    ),
    r'eventId': PropertySchema(id: 8, name: r'eventId', type: IsarType.string),
    r'groupId': PropertySchema(id: 9, name: r'groupId', type: IsarType.string),
    r'hasMedia': PropertySchema(id: 10, name: r'hasMedia', type: IsarType.bool),
    r'kind': PropertySchema(id: 11, name: r'kind', type: IsarType.long),
    r'pTagRefs': PropertySchema(
      id: 12,
      name: r'pTagRefs',
      type: IsarType.stringList,
    ),
    r'rawEventJson': PropertySchema(
      id: 13,
      name: r'rawEventJson',
      type: IsarType.string,
    ),
    r'replyToEventId': PropertySchema(
      id: 14,
      name: r'replyToEventId',
      type: IsarType.string,
    ),
    r'rootEventId': PropertySchema(
      id: 15,
      name: r'rootEventId',
      type: IsarType.string,
    ),
    r'sig': PropertySchema(id: 16, name: r'sig', type: IsarType.string),
    r'signedNostrEvent': PropertySchema(
      id: 17,
      name: r'signedNostrEvent',
      type: IsarType.string,
    ),
    r'subject': PropertySchema(id: 18, name: r'subject', type: IsarType.string),
    r'tTags': PropertySchema(id: 19, name: r'tTags', type: IsarType.stringList),
    r'type': PropertySchema(
      id: 20,
      name: r'type',
      type: IsarType.string,
      enumMap: _NoteModeltypeEnumValueMap,
    ),
  },

  estimateSize: _noteModelEstimateSize,
  serialize: _noteModelSerialize,
  deserialize: _noteModelDeserialize,
  deserializeProp: _noteModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'eventId': IndexSchema(
      id: -2707901133518603130,
      name: r'eventId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'eventId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'authorPubkey': IndexSchema(
      id: -3090179999305958066,
      name: r'authorPubkey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'authorPubkey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'kind': IndexSchema(
      id: 1484550194077596484,
      name: r'kind',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'kind',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'channelId': IndexSchema(
      id: -8352446570702114471,
      name: r'channelId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'channelId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'groupId': IndexSchema(
      id: -8523216633229774932,
      name: r'groupId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'groupId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'conversationId': IndexSchema(
      id: 2945908346256754300,
      name: r'conversationId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversationId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'rootEventId': IndexSchema(
      id: 4630125266856525042,
      name: r'rootEventId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'rootEventId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'replyToEventId': IndexSchema(
      id: -8252228501288249794,
      name: r'replyToEventId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'replyToEventId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'created': IndexSchema(
      id: 9089682803336859617,
      name: r'created',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'created',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'hasMedia': IndexSchema(
      id: 1924470543478053751,
      name: r'hasMedia',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'hasMedia',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'MediaAttachment': MediaAttachmentSchema},

  getId: _noteModelGetId,
  getLinks: _noteModelGetLinks,
  attach: _noteModelAttach,
  version: '3.3.2',
);

int _noteModelEstimateSize(
  NoteModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.attachments.length * 3;
  {
    final offsets = allOffsets[MediaAttachment]!;
    for (var i = 0; i < object.attachments.length; i++) {
      final value = object.attachments[i];
      bytesCount += MediaAttachmentSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.authorPubkey.length * 3;
  {
    final value = object.groupId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.eTagRefs.length * 3;
  {
    for (var i = 0; i < object.eTagRefs.length; i++) {
      final value = object.eTagRefs[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.embeddedNoteJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.eventId.length * 3;
  {
    final value = object.privateGroupId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.pTagRefs.length * 3;
  {
    for (var i = 0; i < object.pTagRefs.length; i++) {
      final value = object.pTagRefs[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.rawEventJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.replyToEventId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.rootEventId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sig.length * 3;
  {
    final value = object.privateMeshEventJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.subject;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.tTags.length * 3;
  {
    for (var i = 0; i < object.tTags.length; i++) {
      final value = object.tTags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.type.name.length * 3;
  return bytesCount;
}

void _noteModelSerialize(
  NoteModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeObjectList<MediaAttachment>(
    offsets[0],
    allOffsets,
    MediaAttachmentSchema.serialize,
    object.attachments,
  );
  writer.writeString(offsets[1], object.authorPubkey);
  writer.writeString(offsets[2], object.groupId);
  writer.writeString(offsets[3], object.content);
  writer.writeLong(offsets[4], object.conversationId);
  writer.writeDateTime(offsets[5], object.created);
  writer.writeStringList(offsets[6], object.eTagRefs);
  writer.writeString(offsets[7], object.embeddedNoteJson);
  writer.writeString(offsets[8], object.eventId);
  writer.writeString(offsets[9], object.privateGroupId);
  writer.writeBool(offsets[10], object.hasMedia);
  writer.writeLong(offsets[11], object.kind);
  writer.writeStringList(offsets[12], object.pTagRefs);
  writer.writeString(offsets[13], object.rawEventJson);
  writer.writeString(offsets[14], object.replyToEventId);
  writer.writeString(offsets[15], object.rootEventId);
  writer.writeString(offsets[16], object.sig);
  writer.writeString(offsets[17], object.privateMeshEventJson);
  writer.writeString(offsets[18], object.subject);
  writer.writeStringList(offsets[19], object.tTags);
  writer.writeString(offsets[20], object.type.name);
}

NoteModel _noteModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NoteModel(
    attachments:
        reader.readObjectList<MediaAttachment>(
          offsets[0],
          MediaAttachmentSchema.deserialize,
          allOffsets,
          MediaAttachment(),
        ) ??
        const [],
    authorPubkey: reader.readString(offsets[1]),
    groupId: reader.readStringOrNull(offsets[2]),
    content: reader.readString(offsets[3]),
    conversationId: reader.readLongOrNull(offsets[4]),
    created: reader.readDateTime(offsets[5]),
    eTagRefs: reader.readStringList(offsets[6]) ?? [],
    embeddedNoteJson: reader.readStringOrNull(offsets[7]),
    eventId: reader.readString(offsets[8]),
    privateGroupId: reader.readStringOrNull(offsets[9]),
    kind: reader.readLongOrNull(offsets[11]) ?? kNoteKind,
    pTagRefs: reader.readStringList(offsets[12]) ?? [],
    rawEventJson: reader.readStringOrNull(offsets[13]),
    replyToEventId: reader.readStringOrNull(offsets[14]),
    rootEventId: reader.readStringOrNull(offsets[15]),
    sig: reader.readString(offsets[16]),
    privateMeshEventJson: reader.readStringOrNull(offsets[17]),
    subject: reader.readStringOrNull(offsets[18]),
    tTags: reader.readStringList(offsets[19]) ?? [],
    type:
        _NoteModeltypeValueEnumMap[reader.readStringOrNull(offsets[20])] ??
        NoteType.text,
  );
  object.hasMedia = reader.readBool(offsets[10]);
  object.id = id;
  return object;
}

P _noteModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readObjectList<MediaAttachment>(
                offset,
                MediaAttachmentSchema.deserialize,
                allOffsets,
                MediaAttachment(),
              ) ??
              const [])
          as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readStringList(offset) ?? []) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset) ?? kNoteKind) as P;
    case 12:
      return (reader.readStringList(offset) ?? []) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readStringList(offset) ?? []) as P;
    case 20:
      return (_NoteModeltypeValueEnumMap[reader.readStringOrNull(offset)] ??
              NoteType.text)
          as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _NoteModeltypeEnumValueMap = {
  r'text': r'text',
  r'image': r'image',
  r'link': r'link',
  r'reference': r'reference',
};
const _NoteModeltypeValueEnumMap = {
  r'text': NoteType.text,
  r'image': NoteType.image,
  r'link': NoteType.link,
  r'reference': NoteType.reference,
};

Id _noteModelGetId(NoteModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _noteModelGetLinks(NoteModel object) {
  return [];
}

void _noteModelAttach(IsarCollection<dynamic> col, Id id, NoteModel object) {
  object.id = id;
}

extension NoteModelByIndex on IsarCollection<NoteModel> {
  Future<NoteModel?> getByEventId(String eventId) {
    return getByIndex(r'eventId', [eventId]);
  }

  NoteModel? getByEventIdSync(String eventId) {
    return getByIndexSync(r'eventId', [eventId]);
  }

  Future<bool> deleteByEventId(String eventId) {
    return deleteByIndex(r'eventId', [eventId]);
  }

  bool deleteByEventIdSync(String eventId) {
    return deleteByIndexSync(r'eventId', [eventId]);
  }

  Future<List<NoteModel?>> getAllByEventId(List<String> eventIdValues) {
    final values = eventIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'eventId', values);
  }

  List<NoteModel?> getAllByEventIdSync(List<String> eventIdValues) {
    final values = eventIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'eventId', values);
  }

  Future<int> deleteAllByEventId(List<String> eventIdValues) {
    final values = eventIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'eventId', values);
  }

  int deleteAllByEventIdSync(List<String> eventIdValues) {
    final values = eventIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'eventId', values);
  }

  Future<Id> putByEventId(NoteModel object) {
    return putByIndex(r'eventId', object);
  }

  Id putByEventIdSync(NoteModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'eventId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEventId(List<NoteModel> objects) {
    return putAllByIndex(r'eventId', objects);
  }

  List<Id> putAllByEventIdSync(
    List<NoteModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'eventId', objects, saveLinks: saveLinks);
  }
}

extension NoteModelQueryWhereSort
    on QueryBuilder<NoteModel, NoteModel, QWhere> {
  QueryBuilder<NoteModel, NoteModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhere> anyKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'kind'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhere> anyConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'conversationId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhere> anyCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'created'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhere> anyHasMedia() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'hasMedia'),
      );
    });
  }
}

extension NoteModelQueryWhere
    on QueryBuilder<NoteModel, NoteModel, QWhereClause> {
  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> eventIdEqualTo(
    String eventId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'eventId', value: [eventId]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> eventIdNotEqualTo(
    String eventId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventId',
                lower: [],
                upper: [eventId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventId',
                lower: [eventId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventId',
                lower: [eventId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'eventId',
                lower: [],
                upper: [eventId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> authorPubkeyEqualTo(
    String authorPubkey,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'authorPubkey',
          value: [authorPubkey],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> authorPubkeyNotEqualTo(
    String authorPubkey,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'authorPubkey',
                lower: [],
                upper: [authorPubkey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'authorPubkey',
                lower: [authorPubkey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'authorPubkey',
                lower: [authorPubkey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'authorPubkey',
                lower: [],
                upper: [authorPubkey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> kindEqualTo(int kind) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'kind', value: [kind]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> kindNotEqualTo(
    int kind,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind',
                lower: [],
                upper: [kind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind',
                lower: [kind],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind',
                lower: [kind],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'kind',
                lower: [],
                upper: [kind],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> kindGreaterThan(
    int kind, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'kind',
          lower: [kind],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> kindLessThan(
    int kind, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'kind',
          lower: [],
          upper: [kind],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> kindBetween(
    int lowerKind,
    int upperKind, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'kind',
          lower: [lowerKind],
          includeLower: includeLower,
          upper: [upperKind],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> groupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'channelId', value: [null]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> groupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'channelId',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> groupIdEqualTo(
    String? groupId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'channelId', value: [groupId]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> groupIdNotEqualTo(
    String? groupId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'channelId',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'channelId',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'channelId',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'channelId',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> privateGroupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'groupId', value: [null]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause>
  privateGroupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'groupId',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> privateGroupIdEqualTo(
    String? privateGroupId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'groupId',
          value: [privateGroupId],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause>
  privateGroupIdNotEqualTo(String? privateGroupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [],
                upper: [privateGroupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [privateGroupId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [privateGroupId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [],
                upper: [privateGroupId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> conversationIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'conversationId', value: [null]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause>
  conversationIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'conversationId',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> conversationIdEqualTo(
    int? conversationId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'conversationId',
          value: [conversationId],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause>
  conversationIdNotEqualTo(int? conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversationId',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversationId',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversationId',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversationId',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause>
  conversationIdGreaterThan(int? conversationId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'conversationId',
          lower: [conversationId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> conversationIdLessThan(
    int? conversationId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'conversationId',
          lower: [],
          upper: [conversationId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> conversationIdBetween(
    int? lowerConversationId,
    int? upperConversationId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'conversationId',
          lower: [lowerConversationId],
          includeLower: includeLower,
          upper: [upperConversationId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> rootEventIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'rootEventId', value: [null]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> rootEventIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'rootEventId',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> rootEventIdEqualTo(
    String? rootEventId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'rootEventId',
          value: [rootEventId],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> rootEventIdNotEqualTo(
    String? rootEventId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'rootEventId',
                lower: [],
                upper: [rootEventId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'rootEventId',
                lower: [rootEventId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'rootEventId',
                lower: [rootEventId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'rootEventId',
                lower: [],
                upper: [rootEventId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> replyToEventIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'replyToEventId', value: [null]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause>
  replyToEventIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'replyToEventId',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> replyToEventIdEqualTo(
    String? replyToEventId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'replyToEventId',
          value: [replyToEventId],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause>
  replyToEventIdNotEqualTo(String? replyToEventId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'replyToEventId',
                lower: [],
                upper: [replyToEventId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'replyToEventId',
                lower: [replyToEventId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'replyToEventId',
                lower: [replyToEventId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'replyToEventId',
                lower: [],
                upper: [replyToEventId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> createdEqualTo(
    DateTime created,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'created', value: [created]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> createdNotEqualTo(
    DateTime created,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created',
                lower: [],
                upper: [created],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created',
                lower: [created],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created',
                lower: [created],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created',
                lower: [],
                upper: [created],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> createdGreaterThan(
    DateTime created, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created',
          lower: [created],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> createdLessThan(
    DateTime created, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created',
          lower: [],
          upper: [created],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> createdBetween(
    DateTime lowerCreated,
    DateTime upperCreated, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created',
          lower: [lowerCreated],
          includeLower: includeLower,
          upper: [upperCreated],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> hasMediaEqualTo(
    bool hasMedia,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'hasMedia', value: [hasMedia]),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterWhereClause> hasMediaNotEqualTo(
    bool hasMedia,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasMedia',
                lower: [],
                upper: [hasMedia],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasMedia',
                lower: [hasMedia],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasMedia',
                lower: [hasMedia],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasMedia',
                lower: [],
                upper: [hasMedia],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension NoteModelQueryFilter
    on QueryBuilder<NoteModel, NoteModel, QFilterCondition> {
  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  attachmentsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachments', length, true, length, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  attachmentsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachments', 0, true, 0, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  attachmentsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachments', 0, false, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  attachmentsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachments', 0, true, length, include);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  attachmentsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachments', length, include, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  attachmentsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'attachments',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> authorPubkeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'authorPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  authorPubkeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'authorPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  authorPubkeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'authorPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> authorPubkeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'authorPubkey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  authorPubkeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'authorPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  authorPubkeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'authorPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  authorPubkeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'authorPubkey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> authorPubkeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'authorPubkey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  authorPubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'authorPubkey', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  authorPubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'authorPubkey', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'channelId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'channelId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'channelId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'channelId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'channelId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'channelId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'channelId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'channelId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'channelId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'channelId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'channelId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'channelId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  conversationIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'conversationId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  conversationIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'conversationId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  conversationIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'conversationId', value: value),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  conversationIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'conversationId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  conversationIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'conversationId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  conversationIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'conversationId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> createdEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created', value: value),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> createdGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> createdLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> createdBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'eTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'eTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'eTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'eTagRefs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'eTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'eTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'eTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'eTagRefs',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'eTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'eTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', length, true, length, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eTagRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', 0, true, 0, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', 0, false, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', 0, true, length, include);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', length, include, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eTagRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'eTagRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'embeddedNoteJson'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'embeddedNoteJson'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'embeddedNoteJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'embeddedNoteJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'embeddedNoteJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'embeddedNoteJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'embeddedNoteJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'embeddedNoteJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'embeddedNoteJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'embeddedNoteJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'embeddedNoteJson', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  embeddedNoteJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'embeddedNoteJson', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'eventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'eventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'eventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'eventId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'eventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'eventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'eventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'eventId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> eventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'eventId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  eventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'eventId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'groupId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'groupId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'groupId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'groupId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'groupId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateGroupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'groupId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> hasMediaEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hasMedia', value: value),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> kindEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: value),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> kindGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kind',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> kindLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kind',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> kindBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pTagRefs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'pTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'pTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'pTagRefs',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'pTagRefs',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', length, true, length, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> pTagRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', 0, true, 0, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', 0, false, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', 0, true, length, include);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', length, include, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  pTagRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'pTagRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'rawEventJson'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'rawEventJson'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rawEventJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'rawEventJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rawEventJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rawEventJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rawEventJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rawEventJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'rawEventJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'rawEventJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'rawEventJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rawEventJsonMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'rawEventJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rawEventJson', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rawEventJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'rawEventJson', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'replyToEventId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'replyToEventId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'replyToEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'replyToEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'replyToEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'replyToEventId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'replyToEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'replyToEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'replyToEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'replyToEventId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'replyToEventId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  replyToEventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'replyToEventId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rootEventIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'rootEventId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rootEventIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'rootEventId'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rootEventIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'rootEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rootEventIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rootEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rootEventIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rootEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rootEventIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rootEventId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rootEventIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'rootEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rootEventIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'rootEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rootEventIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'rootEventId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> rootEventIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'rootEventId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rootEventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rootEventId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  rootEventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'rootEventId', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sig',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sig',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sig',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sig',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sig',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sig',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sig',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sig',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sig', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> sigIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sig', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'signedNostrEvent'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'signedNostrEvent'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'signedNostrEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'signedNostrEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'signedNostrEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'signedNostrEvent',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'signedNostrEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'signedNostrEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'signedNostrEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'signedNostrEvent',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'signedNostrEvent', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  privateMeshEventJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'signedNostrEvent', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'subject'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'subject'),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'subject',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'subject',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'subject',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'subject',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'subject',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'subject',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'subject',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'subject',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> subjectIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'subject', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  subjectIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'subject', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tTags',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsElementMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tTags',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tTags', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tTags', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', length, true, length, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', 0, true, 0, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', 0, false, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', 0, true, length, include);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition>
  tTagsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', length, include, 999999, true);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> tTagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tTags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeEqualTo(
    NoteType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeGreaterThan(
    NoteType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeLessThan(
    NoteType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeBetween(
    NoteType lower,
    NoteType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: ''),
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'type', value: ''),
      );
    });
  }
}

extension NoteModelQueryObject
    on QueryBuilder<NoteModel, NoteModel, QFilterCondition> {
  QueryBuilder<NoteModel, NoteModel, QAfterFilterCondition> attachmentsElement(
    FilterQuery<MediaAttachment> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'attachments');
    });
  }
}

extension NoteModelQueryLinks
    on QueryBuilder<NoteModel, NoteModel, QFilterCondition> {}

extension NoteModelQuerySortBy on QueryBuilder<NoteModel, NoteModel, QSortBy> {
  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByAuthorPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByAuthorPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByCreatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByEmbeddedNoteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy>
  sortByEmbeddedNoteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByPrivateGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByPrivateGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByHasMedia() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasMedia', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByHasMediaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasMedia', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByRawEventJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawEventJson', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByRawEventJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawEventJson', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByReplyToEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByReplyToEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByRootEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByRootEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortBySig() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortBySigDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy>
  sortByPrivateMeshEventJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signedNostrEvent', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy>
  sortByPrivateMeshEventJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signedNostrEvent', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortBySubject() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subject', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortBySubjectDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subject', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension NoteModelQuerySortThenBy
    on QueryBuilder<NoteModel, NoteModel, QSortThenBy> {
  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByAuthorPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByAuthorPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByCreatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByEmbeddedNoteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy>
  thenByEmbeddedNoteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByPrivateGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByPrivateGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByHasMedia() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasMedia', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByHasMediaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasMedia', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByRawEventJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawEventJson', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByRawEventJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawEventJson', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByReplyToEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByReplyToEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByRootEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByRootEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenBySig() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenBySigDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy>
  thenByPrivateMeshEventJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signedNostrEvent', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy>
  thenByPrivateMeshEventJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signedNostrEvent', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenBySubject() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subject', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenBySubjectDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subject', Sort.desc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension NoteModelQueryWhereDistinct
    on QueryBuilder<NoteModel, NoteModel, QDistinct> {
  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByAuthorPubkey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorPubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByGroupId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'channelId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByContent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId');
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created');
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByETagRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eTagRefs');
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByEmbeddedNoteJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'embeddedNoteJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByEventId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByPrivateGroupId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByHasMedia() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasMedia');
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind');
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByPTagRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pTagRefs');
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByRawEventJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawEventJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByReplyToEventId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'replyToEventId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByRootEventId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rootEventId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctBySig({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sig', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByPrivateMeshEventJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'signedNostrEvent',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctBySubject({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subject', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByTTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tTags');
    });
  }

  QueryBuilder<NoteModel, NoteModel, QDistinct> distinctByType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type', caseSensitive: caseSensitive);
    });
  }
}

extension NoteModelQueryProperty
    on QueryBuilder<NoteModel, NoteModel, QQueryProperty> {
  QueryBuilder<NoteModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<NoteModel, List<MediaAttachment>, QQueryOperations>
  attachmentsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachments');
    });
  }

  QueryBuilder<NoteModel, String, QQueryOperations> authorPubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorPubkey');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'channelId');
    });
  }

  QueryBuilder<NoteModel, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<NoteModel, int?, QQueryOperations> conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<NoteModel, DateTime, QQueryOperations> createdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created');
    });
  }

  QueryBuilder<NoteModel, List<String>, QQueryOperations> eTagRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eTagRefs');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations>
  embeddedNoteJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'embeddedNoteJson');
    });
  }

  QueryBuilder<NoteModel, String, QQueryOperations> eventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventId');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations> privateGroupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<NoteModel, bool, QQueryOperations> hasMediaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasMedia');
    });
  }

  QueryBuilder<NoteModel, int, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<NoteModel, List<String>, QQueryOperations> pTagRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pTagRefs');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations> rawEventJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawEventJson');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations> replyToEventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'replyToEventId');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations> rootEventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rootEventId');
    });
  }

  QueryBuilder<NoteModel, String, QQueryOperations> sigProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sig');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations>
  privateMeshEventJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signedNostrEvent');
    });
  }

  QueryBuilder<NoteModel, String?, QQueryOperations> subjectProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subject');
    });
  }

  QueryBuilder<NoteModel, List<String>, QQueryOperations> tTagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tTags');
    });
  }

  QueryBuilder<NoteModel, NoteType, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}
