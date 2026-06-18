// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_queue_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEventQueueModelCollection on Isar {
  IsarCollection<EventQueueModel> get eventQueueModels => this.collection();
}

const EventQueueModelSchema = CollectionSchema(
  name: r'EventQueue',
  id: 8017143989177430287,
  properties: {
    r'authorPubkey': PropertySchema(
      id: 0,
      name: r'authorPubkey',
      type: IsarType.string,
    ),
    r'content': PropertySchema(id: 1, name: r'content', type: IsarType.string),
    r'created': PropertySchema(
      id: 2,
      name: r'created',
      type: IsarType.dateTime,
    ),
    r'dTag': PropertySchema(id: 3, name: r'dTag', type: IsarType.string),
    r'eTagRefs': PropertySchema(
      id: 4,
      name: r'eTagRefs',
      type: IsarType.stringList,
    ),
    r'embeddedNoteJson': PropertySchema(
      id: 5,
      name: r'embeddedNoteJson',
      type: IsarType.string,
    ),
    r'enqueuedAt': PropertySchema(
      id: 6,
      name: r'enqueuedAt',
      type: IsarType.dateTime,
    ),
    r'eventId': PropertySchema(id: 7, name: r'eventId', type: IsarType.string),
    r'expirationSec': PropertySchema(
      id: 8,
      name: r'expirationSec',
      type: IsarType.long,
    ),
    r'hTag': PropertySchema(id: 9, name: r'hTag', type: IsarType.string),
    r'imeta': PropertySchema(
      id: 10,
      name: r'imeta',
      type: IsarType.objectList,

      target: r'MediaAttachment',
    ),
    r'kind': PropertySchema(id: 11, name: r'kind', type: IsarType.long),
    r'pTagRefs': PropertySchema(
      id: 12,
      name: r'pTagRefs',
      type: IsarType.stringList,
    ),
    r'quoteKind': PropertySchema(
      id: 13,
      name: r'quoteKind',
      type: IsarType.long,
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
    r'sentCount': PropertySchema(
      id: 16,
      name: r'sentCount',
      type: IsarType.long,
    ),
    r'serverTags': PropertySchema(
      id: 17,
      name: r'serverTags',
      type: IsarType.stringList,
    ),
    r'sig': PropertySchema(id: 18, name: r'sig', type: IsarType.string),
    r'tTags': PropertySchema(id: 19, name: r'tTags', type: IsarType.stringList),
  },

  estimateSize: _eventQueueModelEstimateSize,
  serialize: _eventQueueModelSerialize,
  deserialize: _eventQueueModelDeserialize,
  deserializeProp: _eventQueueModelDeserializeProp,
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
  },
  links: {},
  embeddedSchemas: {r'MediaAttachment': MediaAttachmentSchema},

  getId: _eventQueueModelGetId,
  getLinks: _eventQueueModelGetLinks,
  attach: _eventQueueModelAttach,
  version: '3.3.2',
);

int _eventQueueModelEstimateSize(
  EventQueueModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.authorPubkey.length * 3;
  bytesCount += 3 + object.content.length * 3;
  {
    final value = object.dTag;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
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
    final value = object.hTag;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.imeta.length * 3;
  {
    final offsets = allOffsets[MediaAttachment]!;
    for (var i = 0; i < object.imeta.length; i++) {
      final value = object.imeta[i];
      bytesCount += MediaAttachmentSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
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
  bytesCount += 3 + object.serverTags.length * 3;
  {
    for (var i = 0; i < object.serverTags.length; i++) {
      final value = object.serverTags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.sig.length * 3;
  bytesCount += 3 + object.tTags.length * 3;
  {
    for (var i = 0; i < object.tTags.length; i++) {
      final value = object.tTags[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _eventQueueModelSerialize(
  EventQueueModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.authorPubkey);
  writer.writeString(offsets[1], object.content);
  writer.writeDateTime(offsets[2], object.created);
  writer.writeString(offsets[3], object.dTag);
  writer.writeStringList(offsets[4], object.eTagRefs);
  writer.writeString(offsets[5], object.embeddedNoteJson);
  writer.writeDateTime(offsets[6], object.enqueuedAt);
  writer.writeString(offsets[7], object.eventId);
  writer.writeLong(offsets[8], object.expirationSec);
  writer.writeString(offsets[9], object.hTag);
  writer.writeObjectList<MediaAttachment>(
    offsets[10],
    allOffsets,
    MediaAttachmentSchema.serialize,
    object.imeta,
  );
  writer.writeLong(offsets[11], object.kind);
  writer.writeStringList(offsets[12], object.pTagRefs);
  writer.writeLong(offsets[13], object.quoteKind);
  writer.writeString(offsets[14], object.replyToEventId);
  writer.writeString(offsets[15], object.rootEventId);
  writer.writeLong(offsets[16], object.sentCount);
  writer.writeStringList(offsets[17], object.serverTags);
  writer.writeString(offsets[18], object.sig);
  writer.writeStringList(offsets[19], object.tTags);
}

EventQueueModel _eventQueueModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EventQueueModel();
  object.authorPubkey = reader.readString(offsets[0]);
  object.content = reader.readString(offsets[1]);
  object.created = reader.readDateTime(offsets[2]);
  object.dTag = reader.readStringOrNull(offsets[3]);
  object.eTagRefs = reader.readStringList(offsets[4]) ?? [];
  object.embeddedNoteJson = reader.readStringOrNull(offsets[5]);
  object.enqueuedAt = reader.readDateTime(offsets[6]);
  object.eventId = reader.readString(offsets[7]);
  object.expirationSec = reader.readLongOrNull(offsets[8]);
  object.hTag = reader.readStringOrNull(offsets[9]);
  object.id = id;
  object.imeta =
      reader.readObjectList<MediaAttachment>(
        offsets[10],
        MediaAttachmentSchema.deserialize,
        allOffsets,
        MediaAttachment(),
      ) ??
      [];
  object.kind = reader.readLong(offsets[11]);
  object.pTagRefs = reader.readStringList(offsets[12]) ?? [];
  object.quoteKind = reader.readLongOrNull(offsets[13]);
  object.replyToEventId = reader.readStringOrNull(offsets[14]);
  object.rootEventId = reader.readStringOrNull(offsets[15]);
  object.sentCount = reader.readLong(offsets[16]);
  object.serverTags = reader.readStringList(offsets[17]) ?? [];
  object.sig = reader.readString(offsets[18]);
  object.tTags = reader.readStringList(offsets[19]) ?? [];
  return object;
}

P _eventQueueModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringList(offset) ?? []) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readObjectList<MediaAttachment>(
                offset,
                MediaAttachmentSchema.deserialize,
                allOffsets,
                MediaAttachment(),
              ) ??
              [])
          as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readStringList(offset) ?? []) as P;
    case 13:
      return (reader.readLongOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    case 17:
      return (reader.readStringList(offset) ?? []) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readStringList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _eventQueueModelGetId(EventQueueModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _eventQueueModelGetLinks(EventQueueModel object) {
  return [];
}

void _eventQueueModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  EventQueueModel object,
) {
  object.id = id;
}

extension EventQueueModelByIndex on IsarCollection<EventQueueModel> {
  Future<EventQueueModel?> getByEventId(String eventId) {
    return getByIndex(r'eventId', [eventId]);
  }

  EventQueueModel? getByEventIdSync(String eventId) {
    return getByIndexSync(r'eventId', [eventId]);
  }

  Future<bool> deleteByEventId(String eventId) {
    return deleteByIndex(r'eventId', [eventId]);
  }

  bool deleteByEventIdSync(String eventId) {
    return deleteByIndexSync(r'eventId', [eventId]);
  }

  Future<List<EventQueueModel?>> getAllByEventId(List<String> eventIdValues) {
    final values = eventIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'eventId', values);
  }

  List<EventQueueModel?> getAllByEventIdSync(List<String> eventIdValues) {
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

  Future<Id> putByEventId(EventQueueModel object) {
    return putByIndex(r'eventId', object);
  }

  Id putByEventIdSync(EventQueueModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'eventId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEventId(List<EventQueueModel> objects) {
    return putAllByIndex(r'eventId', objects);
  }

  List<Id> putAllByEventIdSync(
    List<EventQueueModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'eventId', objects, saveLinks: saveLinks);
  }
}

extension EventQueueModelQueryWhereSort
    on QueryBuilder<EventQueueModel, EventQueueModel, QWhere> {
  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension EventQueueModelQueryWhere
    on QueryBuilder<EventQueueModel, EventQueueModel, QWhereClause> {
  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhereClause>
  eventIdEqualTo(String eventId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'eventId', value: [eventId]),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterWhereClause>
  eventIdNotEqualTo(String eventId) {
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
}

extension EventQueueModelQueryFilter
    on QueryBuilder<EventQueueModel, EventQueueModel, QFilterCondition> {
  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  authorPubkeyEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  authorPubkeyBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  authorPubkeyMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  authorPubkeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'authorPubkey', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  authorPubkeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'authorPubkey', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentGreaterThan(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentLessThan(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  createdEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created', value: value),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  createdGreaterThan(DateTime value, {bool include = false}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  createdLessThan(DateTime value, {bool include = false}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  createdBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'dTag'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'dTag'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dTag',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'dTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'dTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'dTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'dTag',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dTag', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  dTagIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'dTag', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eTagRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'eTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eTagRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'eTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eTagRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', length, true, length, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eTagRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', 0, true, 0, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eTagRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', 0, false, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eTagRefsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', 0, true, length, include);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eTagRefsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'eTagRefs', length, include, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  embeddedNoteJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'embeddedNoteJson'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  embeddedNoteJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'embeddedNoteJson'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  embeddedNoteJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'embeddedNoteJson', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  embeddedNoteJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'embeddedNoteJson', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  enqueuedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'enqueuedAt', value: value),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  enqueuedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'enqueuedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  enqueuedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'enqueuedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  enqueuedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'enqueuedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdGreaterThan(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdLessThan(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'eventId', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  eventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'eventId', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  expirationSecIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'expirationSec'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  expirationSecIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'expirationSec'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  expirationSecEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'expirationSec', value: value),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  expirationSecGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'expirationSec',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  expirationSecLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'expirationSec',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  expirationSecBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'expirationSec',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'hTag'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'hTag'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'hTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'hTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'hTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'hTag',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'hTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'hTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'hTag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'hTag',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hTag', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  hTagIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'hTag', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  idBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  imetaLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imeta', length, true, length, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  imetaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imeta', 0, true, 0, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  imetaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imeta', 0, false, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  imetaLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imeta', 0, true, length, include);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  imetaLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'imeta', length, include, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  imetaLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'imeta',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  kindEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: value),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  kindGreaterThan(int value, {bool include = false}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  kindLessThan(int value, {bool include = false}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  kindBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  pTagRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  pTagRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pTagRefs', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  pTagRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', length, true, length, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  pTagRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', 0, true, 0, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  pTagRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', 0, false, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  pTagRefsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', 0, true, length, include);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  pTagRefsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'pTagRefs', length, include, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  quoteKindIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'quoteKind'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  quoteKindIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'quoteKind'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  quoteKindEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'quoteKind', value: value),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  quoteKindGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'quoteKind',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  quoteKindLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'quoteKind',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  quoteKindBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'quoteKind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  replyToEventIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'replyToEventId'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  replyToEventIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'replyToEventId'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  replyToEventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'replyToEventId', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  replyToEventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'replyToEventId', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'rootEventId'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'rootEventId'),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdLessThan(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rootEventId', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  rootEventIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'rootEventId', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sentCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sentCount', value: value),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sentCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sentCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sentCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sentCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sentCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sentCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'serverTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'serverTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'serverTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'serverTags',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'serverTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'serverTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'serverTags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'serverTags',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'serverTags', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'serverTags', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'serverTags', length, true, length, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'serverTags', 0, true, 0, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'serverTags', 0, false, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'serverTags', 0, true, length, include);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'serverTags', length, include, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  serverTagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'serverTags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigGreaterThan(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigLessThan(String value, {bool include = false, bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sig', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  sigIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sig', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsElementEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsElementBetween(
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsElementMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tTags', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tTags', value: ''),
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', length, true, length, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', 0, true, 0, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', 0, false, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', 0, true, length, include);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tTags', length, include, 999999, true);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  tTagsLengthBetween(
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
}

extension EventQueueModelQueryObject
    on QueryBuilder<EventQueueModel, EventQueueModel, QFilterCondition> {
  QueryBuilder<EventQueueModel, EventQueueModel, QAfterFilterCondition>
  imetaElement(FilterQuery<MediaAttachment> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'imeta');
    });
  }
}

extension EventQueueModelQueryLinks
    on QueryBuilder<EventQueueModel, EventQueueModel, QFilterCondition> {}

extension EventQueueModelQuerySortBy
    on QueryBuilder<EventQueueModel, EventQueueModel, QSortBy> {
  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByAuthorPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByAuthorPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortByCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByCreatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortByDTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dTag', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByDTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dTag', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByEmbeddedNoteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByEmbeddedNoteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByEnqueuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByEnqueuedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortByEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByExpirationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationSec', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByExpirationSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationSec', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortByHTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hTag', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByHTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hTag', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByQuoteKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quoteKind', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByQuoteKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quoteKind', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByReplyToEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByReplyToEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByRootEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortByRootEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortBySentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentCount', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  sortBySentCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentCount', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortBySig() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> sortBySigDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.desc);
    });
  }
}

extension EventQueueModelQuerySortThenBy
    on QueryBuilder<EventQueueModel, EventQueueModel, QSortThenBy> {
  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByAuthorPubkey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByAuthorPubkeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authorPubkey', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenByCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByCreatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenByDTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dTag', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByDTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dTag', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByEmbeddedNoteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByEmbeddedNoteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'embeddedNoteJson', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByEnqueuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByEnqueuedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenByEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventId', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByExpirationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationSec', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByExpirationSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationSec', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenByHTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hTag', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByHTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hTag', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByQuoteKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quoteKind', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByQuoteKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quoteKind', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByReplyToEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByReplyToEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToEventId', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByRootEventId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenByRootEventIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootEventId', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenBySentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentCount', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy>
  thenBySentCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentCount', Sort.desc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenBySig() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.asc);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QAfterSortBy> thenBySigDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sig', Sort.desc);
    });
  }
}

extension EventQueueModelQueryWhereDistinct
    on QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> {
  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByAuthorPubkey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authorPubkey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> distinctByContent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByCreated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> distinctByDTag({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dTag', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByETagRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eTagRefs');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByEmbeddedNoteJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'embeddedNoteJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByEnqueuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enqueuedAt');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> distinctByEventId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByExpirationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expirationSec');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> distinctByHTag({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hTag', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> distinctByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByPTagRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pTagRefs');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByQuoteKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quoteKind');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByReplyToEventId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'replyToEventId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByRootEventId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rootEventId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctBySentCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sentCount');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct>
  distinctByServerTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverTags');
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> distinctBySig({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sig', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EventQueueModel, EventQueueModel, QDistinct> distinctByTTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tTags');
    });
  }
}

extension EventQueueModelQueryProperty
    on QueryBuilder<EventQueueModel, EventQueueModel, QQueryProperty> {
  QueryBuilder<EventQueueModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EventQueueModel, String, QQueryOperations>
  authorPubkeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authorPubkey');
    });
  }

  QueryBuilder<EventQueueModel, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<EventQueueModel, DateTime, QQueryOperations> createdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created');
    });
  }

  QueryBuilder<EventQueueModel, String?, QQueryOperations> dTagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dTag');
    });
  }

  QueryBuilder<EventQueueModel, List<String>, QQueryOperations>
  eTagRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eTagRefs');
    });
  }

  QueryBuilder<EventQueueModel, String?, QQueryOperations>
  embeddedNoteJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'embeddedNoteJson');
    });
  }

  QueryBuilder<EventQueueModel, DateTime, QQueryOperations>
  enqueuedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enqueuedAt');
    });
  }

  QueryBuilder<EventQueueModel, String, QQueryOperations> eventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventId');
    });
  }

  QueryBuilder<EventQueueModel, int?, QQueryOperations>
  expirationSecProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expirationSec');
    });
  }

  QueryBuilder<EventQueueModel, String?, QQueryOperations> hTagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hTag');
    });
  }

  QueryBuilder<EventQueueModel, List<MediaAttachment>, QQueryOperations>
  imetaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imeta');
    });
  }

  QueryBuilder<EventQueueModel, int, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<EventQueueModel, List<String>, QQueryOperations>
  pTagRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pTagRefs');
    });
  }

  QueryBuilder<EventQueueModel, int?, QQueryOperations> quoteKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quoteKind');
    });
  }

  QueryBuilder<EventQueueModel, String?, QQueryOperations>
  replyToEventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'replyToEventId');
    });
  }

  QueryBuilder<EventQueueModel, String?, QQueryOperations>
  rootEventIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rootEventId');
    });
  }

  QueryBuilder<EventQueueModel, int, QQueryOperations> sentCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sentCount');
    });
  }

  QueryBuilder<EventQueueModel, List<String>, QQueryOperations>
  serverTagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverTags');
    });
  }

  QueryBuilder<EventQueueModel, String, QQueryOperations> sigProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sig');
    });
  }

  QueryBuilder<EventQueueModel, List<String>, QQueryOperations>
  tTagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tTags');
    });
  }
}
