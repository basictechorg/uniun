// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'draft_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DraftEntity {

 String get draftId; String get content; String? get rootEventId; String? get replyToEventId; List<String> get eTagRefs; List<String> get pTagRefs; List<String> get tTags; DateTime get createdAt; DateTime get updatedAt;/// References to OTHER drafts (by `draftId` UUID). Held separately from
/// [eTagRefs] (which only carries real event ids). Synced cross-device via
/// NIP-37 inner-event `["d-ref", uuid]` tags so the same UUIDs resolve on
/// every device. Dropped or rewritten to event ids at publish time.
 List<String> get draftRefIds;/// Non-null once this draft has been published. The row becomes a brief
/// tombstone carrying the UUID→event-id mapping so referencing drafts
/// (on this and other devices) can resolve their [draftRefIds].
 String? get publishedAsEventId;/// Media attached to the draft. Staged **locally only** (bytes live in the
/// shared media cache, keyed by sha256) — NOT uploaded to Blossom while a
/// draft. `localPath` is patched in from the cache on read so the draft
/// renders like any note; `serverUrls` stays empty until the draft is
/// published, at which point the bytes are uploaded and `imeta` is built.
 List<MediaBlobEntity> get attachments;
/// Create a copy of DraftEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DraftEntityCopyWith<DraftEntity> get copyWith => _$DraftEntityCopyWithImpl<DraftEntity>(this as DraftEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DraftEntity&&(identical(other.draftId, draftId) || other.draftId == draftId)&&(identical(other.content, content) || other.content == content)&&(identical(other.rootEventId, rootEventId) || other.rootEventId == rootEventId)&&(identical(other.replyToEventId, replyToEventId) || other.replyToEventId == replyToEventId)&&const DeepCollectionEquality().equals(other.eTagRefs, eTagRefs)&&const DeepCollectionEquality().equals(other.pTagRefs, pTagRefs)&&const DeepCollectionEquality().equals(other.tTags, tTags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.draftRefIds, draftRefIds)&&(identical(other.publishedAsEventId, publishedAsEventId) || other.publishedAsEventId == publishedAsEventId)&&const DeepCollectionEquality().equals(other.attachments, attachments));
}


@override
int get hashCode => Object.hash(runtimeType,draftId,content,rootEventId,replyToEventId,const DeepCollectionEquality().hash(eTagRefs),const DeepCollectionEquality().hash(pTagRefs),const DeepCollectionEquality().hash(tTags),createdAt,updatedAt,const DeepCollectionEquality().hash(draftRefIds),publishedAsEventId,const DeepCollectionEquality().hash(attachments));

@override
String toString() {
  return 'DraftEntity(draftId: $draftId, content: $content, rootEventId: $rootEventId, replyToEventId: $replyToEventId, eTagRefs: $eTagRefs, pTagRefs: $pTagRefs, tTags: $tTags, createdAt: $createdAt, updatedAt: $updatedAt, draftRefIds: $draftRefIds, publishedAsEventId: $publishedAsEventId, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class $DraftEntityCopyWith<$Res>  {
  factory $DraftEntityCopyWith(DraftEntity value, $Res Function(DraftEntity) _then) = _$DraftEntityCopyWithImpl;
@useResult
$Res call({
 String draftId, String content, String? rootEventId, String? replyToEventId, List<String> eTagRefs, List<String> pTagRefs, List<String> tTags, DateTime createdAt, DateTime updatedAt, List<String> draftRefIds, String? publishedAsEventId, List<MediaBlobEntity> attachments
});




}
/// @nodoc
class _$DraftEntityCopyWithImpl<$Res>
    implements $DraftEntityCopyWith<$Res> {
  _$DraftEntityCopyWithImpl(this._self, this._then);

  final DraftEntity _self;
  final $Res Function(DraftEntity) _then;

/// Create a copy of DraftEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? draftId = null,Object? content = null,Object? rootEventId = freezed,Object? replyToEventId = freezed,Object? eTagRefs = null,Object? pTagRefs = null,Object? tTags = null,Object? createdAt = null,Object? updatedAt = null,Object? draftRefIds = null,Object? publishedAsEventId = freezed,Object? attachments = null,}) {
  return _then(_self.copyWith(
draftId: null == draftId ? _self.draftId : draftId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,rootEventId: freezed == rootEventId ? _self.rootEventId : rootEventId // ignore: cast_nullable_to_non_nullable
as String?,replyToEventId: freezed == replyToEventId ? _self.replyToEventId : replyToEventId // ignore: cast_nullable_to_non_nullable
as String?,eTagRefs: null == eTagRefs ? _self.eTagRefs : eTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,pTagRefs: null == pTagRefs ? _self.pTagRefs : pTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,tTags: null == tTags ? _self.tTags : tTags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,draftRefIds: null == draftRefIds ? _self.draftRefIds : draftRefIds // ignore: cast_nullable_to_non_nullable
as List<String>,publishedAsEventId: freezed == publishedAsEventId ? _self.publishedAsEventId : publishedAsEventId // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MediaBlobEntity>,
  ));
}

}


/// Adds pattern-matching-related methods to [DraftEntity].
extension DraftEntityPatterns on DraftEntity {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DraftEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DraftEntity() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DraftEntity value)  $default,){
final _that = this;
switch (_that) {
case _DraftEntity():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DraftEntity value)?  $default,){
final _that = this;
switch (_that) {
case _DraftEntity() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String draftId,  String content,  String? rootEventId,  String? replyToEventId,  List<String> eTagRefs,  List<String> pTagRefs,  List<String> tTags,  DateTime createdAt,  DateTime updatedAt,  List<String> draftRefIds,  String? publishedAsEventId,  List<MediaBlobEntity> attachments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DraftEntity() when $default != null:
return $default(_that.draftId,_that.content,_that.rootEventId,_that.replyToEventId,_that.eTagRefs,_that.pTagRefs,_that.tTags,_that.createdAt,_that.updatedAt,_that.draftRefIds,_that.publishedAsEventId,_that.attachments);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String draftId,  String content,  String? rootEventId,  String? replyToEventId,  List<String> eTagRefs,  List<String> pTagRefs,  List<String> tTags,  DateTime createdAt,  DateTime updatedAt,  List<String> draftRefIds,  String? publishedAsEventId,  List<MediaBlobEntity> attachments)  $default,) {final _that = this;
switch (_that) {
case _DraftEntity():
return $default(_that.draftId,_that.content,_that.rootEventId,_that.replyToEventId,_that.eTagRefs,_that.pTagRefs,_that.tTags,_that.createdAt,_that.updatedAt,_that.draftRefIds,_that.publishedAsEventId,_that.attachments);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String draftId,  String content,  String? rootEventId,  String? replyToEventId,  List<String> eTagRefs,  List<String> pTagRefs,  List<String> tTags,  DateTime createdAt,  DateTime updatedAt,  List<String> draftRefIds,  String? publishedAsEventId,  List<MediaBlobEntity> attachments)?  $default,) {final _that = this;
switch (_that) {
case _DraftEntity() when $default != null:
return $default(_that.draftId,_that.content,_that.rootEventId,_that.replyToEventId,_that.eTagRefs,_that.pTagRefs,_that.tTags,_that.createdAt,_that.updatedAt,_that.draftRefIds,_that.publishedAsEventId,_that.attachments);case _:
  return null;

}
}

}

/// @nodoc


class _DraftEntity implements DraftEntity {
  const _DraftEntity({required this.draftId, required this.content, this.rootEventId, this.replyToEventId, required final  List<String> eTagRefs, required final  List<String> pTagRefs, required final  List<String> tTags, required this.createdAt, required this.updatedAt, final  List<String> draftRefIds = const <String>[], this.publishedAsEventId, final  List<MediaBlobEntity> attachments = const <MediaBlobEntity>[]}): _eTagRefs = eTagRefs,_pTagRefs = pTagRefs,_tTags = tTags,_draftRefIds = draftRefIds,_attachments = attachments;
  

@override final  String draftId;
@override final  String content;
@override final  String? rootEventId;
@override final  String? replyToEventId;
 final  List<String> _eTagRefs;
@override List<String> get eTagRefs {
  if (_eTagRefs is EqualUnmodifiableListView) return _eTagRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_eTagRefs);
}

 final  List<String> _pTagRefs;
@override List<String> get pTagRefs {
  if (_pTagRefs is EqualUnmodifiableListView) return _pTagRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pTagRefs);
}

 final  List<String> _tTags;
@override List<String> get tTags {
  if (_tTags is EqualUnmodifiableListView) return _tTags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tTags);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
/// References to OTHER drafts (by `draftId` UUID). Held separately from
/// [eTagRefs] (which only carries real event ids). Synced cross-device via
/// NIP-37 inner-event `["d-ref", uuid]` tags so the same UUIDs resolve on
/// every device. Dropped or rewritten to event ids at publish time.
 final  List<String> _draftRefIds;
/// References to OTHER drafts (by `draftId` UUID). Held separately from
/// [eTagRefs] (which only carries real event ids). Synced cross-device via
/// NIP-37 inner-event `["d-ref", uuid]` tags so the same UUIDs resolve on
/// every device. Dropped or rewritten to event ids at publish time.
@override@JsonKey() List<String> get draftRefIds {
  if (_draftRefIds is EqualUnmodifiableListView) return _draftRefIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_draftRefIds);
}

/// Non-null once this draft has been published. The row becomes a brief
/// tombstone carrying the UUID→event-id mapping so referencing drafts
/// (on this and other devices) can resolve their [draftRefIds].
@override final  String? publishedAsEventId;
/// Media attached to the draft. Staged **locally only** (bytes live in the
/// shared media cache, keyed by sha256) — NOT uploaded to Blossom while a
/// draft. `localPath` is patched in from the cache on read so the draft
/// renders like any note; `serverUrls` stays empty until the draft is
/// published, at which point the bytes are uploaded and `imeta` is built.
 final  List<MediaBlobEntity> _attachments;
/// Media attached to the draft. Staged **locally only** (bytes live in the
/// shared media cache, keyed by sha256) — NOT uploaded to Blossom while a
/// draft. `localPath` is patched in from the cache on read so the draft
/// renders like any note; `serverUrls` stays empty until the draft is
/// published, at which point the bytes are uploaded and `imeta` is built.
@override@JsonKey() List<MediaBlobEntity> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}


/// Create a copy of DraftEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DraftEntityCopyWith<_DraftEntity> get copyWith => __$DraftEntityCopyWithImpl<_DraftEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DraftEntity&&(identical(other.draftId, draftId) || other.draftId == draftId)&&(identical(other.content, content) || other.content == content)&&(identical(other.rootEventId, rootEventId) || other.rootEventId == rootEventId)&&(identical(other.replyToEventId, replyToEventId) || other.replyToEventId == replyToEventId)&&const DeepCollectionEquality().equals(other._eTagRefs, _eTagRefs)&&const DeepCollectionEquality().equals(other._pTagRefs, _pTagRefs)&&const DeepCollectionEquality().equals(other._tTags, _tTags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._draftRefIds, _draftRefIds)&&(identical(other.publishedAsEventId, publishedAsEventId) || other.publishedAsEventId == publishedAsEventId)&&const DeepCollectionEquality().equals(other._attachments, _attachments));
}


@override
int get hashCode => Object.hash(runtimeType,draftId,content,rootEventId,replyToEventId,const DeepCollectionEquality().hash(_eTagRefs),const DeepCollectionEquality().hash(_pTagRefs),const DeepCollectionEquality().hash(_tTags),createdAt,updatedAt,const DeepCollectionEquality().hash(_draftRefIds),publishedAsEventId,const DeepCollectionEquality().hash(_attachments));

@override
String toString() {
  return 'DraftEntity(draftId: $draftId, content: $content, rootEventId: $rootEventId, replyToEventId: $replyToEventId, eTagRefs: $eTagRefs, pTagRefs: $pTagRefs, tTags: $tTags, createdAt: $createdAt, updatedAt: $updatedAt, draftRefIds: $draftRefIds, publishedAsEventId: $publishedAsEventId, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class _$DraftEntityCopyWith<$Res> implements $DraftEntityCopyWith<$Res> {
  factory _$DraftEntityCopyWith(_DraftEntity value, $Res Function(_DraftEntity) _then) = __$DraftEntityCopyWithImpl;
@override @useResult
$Res call({
 String draftId, String content, String? rootEventId, String? replyToEventId, List<String> eTagRefs, List<String> pTagRefs, List<String> tTags, DateTime createdAt, DateTime updatedAt, List<String> draftRefIds, String? publishedAsEventId, List<MediaBlobEntity> attachments
});




}
/// @nodoc
class __$DraftEntityCopyWithImpl<$Res>
    implements _$DraftEntityCopyWith<$Res> {
  __$DraftEntityCopyWithImpl(this._self, this._then);

  final _DraftEntity _self;
  final $Res Function(_DraftEntity) _then;

/// Create a copy of DraftEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? draftId = null,Object? content = null,Object? rootEventId = freezed,Object? replyToEventId = freezed,Object? eTagRefs = null,Object? pTagRefs = null,Object? tTags = null,Object? createdAt = null,Object? updatedAt = null,Object? draftRefIds = null,Object? publishedAsEventId = freezed,Object? attachments = null,}) {
  return _then(_DraftEntity(
draftId: null == draftId ? _self.draftId : draftId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,rootEventId: freezed == rootEventId ? _self.rootEventId : rootEventId // ignore: cast_nullable_to_non_nullable
as String?,replyToEventId: freezed == replyToEventId ? _self.replyToEventId : replyToEventId // ignore: cast_nullable_to_non_nullable
as String?,eTagRefs: null == eTagRefs ? _self._eTagRefs : eTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,pTagRefs: null == pTagRefs ? _self._pTagRefs : pTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,tTags: null == tTags ? _self._tTags : tTags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,draftRefIds: null == draftRefIds ? _self._draftRefIds : draftRefIds // ignore: cast_nullable_to_non_nullable
as List<String>,publishedAsEventId: freezed == publishedAsEventId ? _self.publishedAsEventId : publishedAsEventId // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MediaBlobEntity>,
  ));
}


}

// dart format on
