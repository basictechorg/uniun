// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetGroupModelCollection on Isar {
  IsarCollection<GroupModel> get groupModels => this.collection();
}

const GroupModelSchema = CollectionSchema(
  name: r'Channel',
  id: 3096422491918372507,
  properties: {
    r'about': PropertySchema(id: 0, name: r'about', type: IsarType.string),
    r'channelId': PropertySchema(
      id: 1,
      name: r'channelId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'creatorPubKey': PropertySchema(
      id: 3,
      name: r'creatorPubKey',
      type: IsarType.string,
    ),
    r'lastMetaEvent': PropertySchema(
      id: 4,
      name: r'lastMetaEvent',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 5, name: r'name', type: IsarType.string),
    r'picture': PropertySchema(id: 6, name: r'picture', type: IsarType.string),
    r'relays': PropertySchema(
      id: 7,
      name: r'relays',
      type: IsarType.stringList,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.long,
    ),
  },

  estimateSize: _groupModelEstimateSize,
  serialize: _groupModelSerialize,
  deserialize: _groupModelDeserialize,
  deserializeProp: _groupModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'channelId': IndexSchema(
      id: -8352446570702114471,
      name: r'channelId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'channelId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _groupModelGetId,
  getLinks: _groupModelGetLinks,
  attach: _groupModelAttach,
  version: '3.3.2',
);

int _groupModelEstimateSize(
  GroupModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.about.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.creatorPubKey.length * 3;
  {
    final value = object.lastMetaEvent;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.picture.length * 3;
  bytesCount += 3 + object.relays.length * 3;
  {
    for (var i = 0; i < object.relays.length; i++) {
      final value = object.relays[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _groupModelSerialize(
  GroupModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.about);
  writer.writeString(offsets[1], object.groupId);
  writer.writeLong(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.creatorPubKey);
  writer.writeString(offsets[4], object.lastMetaEvent);
  writer.writeString(offsets[5], object.name);
  writer.writeString(offsets[6], object.picture);
  writer.writeStringList(offsets[7], object.relays);
  writer.writeLong(offsets[8], object.updatedAt);
}

GroupModel _groupModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = GroupModel();
  object.about = reader.readString(offsets[0]);
  object.groupId = reader.readString(offsets[1]);
  object.createdAt = reader.readLong(offsets[2]);
  object.creatorPubKey = reader.readString(offsets[3]);
  object.id = id;
  object.lastMetaEvent = reader.readStringOrNull(offsets[4]);
  object.name = reader.readString(offsets[5]);
  object.picture = reader.readString(offsets[6]);
  object.relays = reader.readStringList(offsets[7]) ?? [];
  object.updatedAt = reader.readLong(offsets[8]);
  return object;
}

P _groupModelDeserializeProp<P>(
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
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringList(offset) ?? []) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _groupModelGetId(GroupModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _groupModelGetLinks(GroupModel object) {
  return [];
}

void _groupModelAttach(IsarCollection<dynamic> col, Id id, GroupModel object) {
  object.id = id;
}

extension GroupModelByIndex on IsarCollection<GroupModel> {
  Future<GroupModel?> getByGroupId(String groupId) {
    return getByIndex(r'channelId', [groupId]);
  }

  GroupModel? getByGroupIdSync(String groupId) {
    return getByIndexSync(r'channelId', [groupId]);
  }

  Future<bool> deleteByGroupId(String groupId) {
    return deleteByIndex(r'channelId', [groupId]);
  }

  bool deleteByGroupIdSync(String groupId) {
    return deleteByIndexSync(r'channelId', [groupId]);
  }

  Future<List<GroupModel?>> getAllByGroupId(List<String> groupIdValues) {
    final values = groupIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'channelId', values);
  }

  List<GroupModel?> getAllByGroupIdSync(List<String> groupIdValues) {
    final values = groupIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'channelId', values);
  }

  Future<int> deleteAllByGroupId(List<String> groupIdValues) {
    final values = groupIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'channelId', values);
  }

  int deleteAllByGroupIdSync(List<String> groupIdValues) {
    final values = groupIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'channelId', values);
  }

  Future<Id> putByGroupId(GroupModel object) {
    return putByIndex(r'channelId', object);
  }

  Id putByGroupIdSync(GroupModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'channelId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByGroupId(List<GroupModel> objects) {
    return putAllByIndex(r'channelId', objects);
  }

  List<Id> putAllByGroupIdSync(
    List<GroupModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'channelId', objects, saveLinks: saveLinks);
  }
}

extension GroupModelQueryWhereSort
    on QueryBuilder<GroupModel, GroupModel, QWhere> {
  QueryBuilder<GroupModel, GroupModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension GroupModelQueryWhere
    on QueryBuilder<GroupModel, GroupModel, QWhereClause> {
  QueryBuilder<GroupModel, GroupModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<GroupModel, GroupModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<GroupModel, GroupModel, QAfterWhereClause> groupIdEqualTo(
    String groupId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'channelId', value: [groupId]),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterWhereClause> groupIdNotEqualTo(
    String groupId,
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
}

extension GroupModelQueryFilter
    on QueryBuilder<GroupModel, GroupModel, QFilterCondition> {
  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'about',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'about',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'about',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> aboutIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'about', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  aboutIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'about', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdEqualTo(
    String value, {
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  groupIdGreaterThan(
    String value, {
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdLessThan(
    String value, {
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdBetween(
    String lower,
    String upper, {
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdStartsWith(
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdEndsWith(
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdContains(
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdMatches(
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'channelId', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'channelId', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> createdAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  createdAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> createdAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'creatorPubKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'creatorPubKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'creatorPubKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'creatorPubKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'creatorPubKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'creatorPubKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'creatorPubKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'creatorPubKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'creatorPubKey', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  creatorPubKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'creatorPubKey', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> idBetween(
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

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastMetaEvent'),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastMetaEvent'),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastMetaEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastMetaEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastMetaEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastMetaEvent',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastMetaEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastMetaEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastMetaEvent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastMetaEvent',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastMetaEvent', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  lastMetaEventIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastMetaEvent', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'picture',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  pictureGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'picture',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'picture',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'picture',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'picture',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'picture',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'picture',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'picture',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> pictureIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'picture', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  pictureIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'picture', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'relays',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'relays',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'relays',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'relays',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'relays',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'relays',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'relays',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'relays',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'relays', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'relays', value: ''),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'relays', length, true, length, true);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> relaysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'relays', 0, true, 0, true);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'relays', 0, false, 999999, true);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'relays', 0, true, length, include);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'relays', length, include, 999999, true);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  relaysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'relays',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> updatedAtEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition>
  updatedAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> updatedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterFilterCondition> updatedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension GroupModelQueryObject
    on QueryBuilder<GroupModel, GroupModel, QFilterCondition> {}

extension GroupModelQueryLinks
    on QueryBuilder<GroupModel, GroupModel, QFilterCondition> {}

extension GroupModelQuerySortBy
    on QueryBuilder<GroupModel, GroupModel, QSortBy> {
  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByAbout() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByAboutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByCreatorPubKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorPubKey', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByCreatorPubKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorPubKey', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByLastMetaEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMetaEvent', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByLastMetaEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMetaEvent', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByPicture() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'picture', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByPictureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'picture', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension GroupModelQuerySortThenBy
    on QueryBuilder<GroupModel, GroupModel, QSortThenBy> {
  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByAbout() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByAboutDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'about', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByCreatorPubKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorPubKey', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByCreatorPubKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorPubKey', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByLastMetaEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMetaEvent', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByLastMetaEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMetaEvent', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByPicture() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'picture', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByPictureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'picture', Sort.desc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension GroupModelQueryWhereDistinct
    on QueryBuilder<GroupModel, GroupModel, QDistinct> {
  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByAbout({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'about', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByGroupId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'channelId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByCreatorPubKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'creatorPubKey',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByLastMetaEvent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastMetaEvent',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByPicture({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'picture', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByRelays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'relays');
    });
  }

  QueryBuilder<GroupModel, GroupModel, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension GroupModelQueryProperty
    on QueryBuilder<GroupModel, GroupModel, QQueryProperty> {
  QueryBuilder<GroupModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<GroupModel, String, QQueryOperations> aboutProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'about');
    });
  }

  QueryBuilder<GroupModel, String, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'channelId');
    });
  }

  QueryBuilder<GroupModel, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<GroupModel, String, QQueryOperations> creatorPubKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'creatorPubKey');
    });
  }

  QueryBuilder<GroupModel, String?, QQueryOperations> lastMetaEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastMetaEvent');
    });
  }

  QueryBuilder<GroupModel, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<GroupModel, String, QQueryOperations> pictureProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'picture');
    });
  }

  QueryBuilder<GroupModel, List<String>, QQueryOperations> relaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'relays');
    });
  }

  QueryBuilder<GroupModel, int, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
