// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'note_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NoteEntity {

 String get id; String get sig; String get authorPubkey; String get content; String? get subject;/// Nostr event kind: 1 feed note, 42 group message, 14/15 DM,
/// 9023 private group message. Stored discriminator of the unified Note
/// collection. Note *roles* (reply/root/reference) are still derived from
/// rootEventId/replyToEventId, not from kind.
 int get kind; NoteType get type; List<String> get eTagRefs; List<String> get pTagRefs; List<String> get tTags; DateTime get created;/// DM conversation id — non-null only when [kind] is 14/15. Used to route
/// replies back to the correct DM conversation.
 int? get conversationId;/// NIP-10 "root" marker — null means this IS a top-level note.
 String? get rootEventId;/// NIP-10 "reply" marker — the direct parent note this replies to.
 String? get replyToEventId;/// Incoming reply count — notes that reference this one. From the edge table.
 int get cachedReplyCount;/// Outgoing reference count — notes this one references. From the edge table.
 int get referenceCount;/// Non-null when this entity was projected from a Kind-42 public group
/// message — used by the Vishnu feed to route taps to the group page
/// instead of the regular thread page. Null for native Kind-1 notes.
 String? get sourceGroupId;/// Non-null when this entity was projected from a NIP-29 private group
/// message. Mutually exclusive with [sourceGroupId].
 String? get sourcePrivateGroupId;/// Pre-rendered chip text shown next to the timestamp on the NoteCard:
///   - `#<name>`  for public group messages
///   - `🔒 <name>` for private group messages
///   - `null`     for native Kind-1 Vishnu notes
/// Resolved by [FeedRepository] at query time from the group/group rows.
 String? get sourceLabel;/// Raw self-contained snapshot of the embedded original (the
/// `embeddedNoteJson` tag / MLS envelope key `"em"`). Source of truth for
/// [quotedNote]; null when this note quotes nothing. A blanked `sig` inside
/// it means the embed failed signature verification (see EmbeddedNoteCodec).
 String? get embeddedNoteJson;/// Pre-resolved one level deep ([quotedNote.quotedNote] is always null).
/// Built from [embeddedNoteJson] (self-contained, retention-immune). Its
/// `sig` is empty when the embed is unverified — the renderer badges it.
 NoteEntity? get quotedNote;/// Pre-resolved attachments. Populated by the data layer when a note is
/// projected from Isar (mirrors how [quotedNote] and [cachedReplyCount]
/// are resolved at query time). UI cards read this directly — no per-
/// card DB lookup.
///
/// Excluded from JSON: this is an in-memory enrichment, not part of the
/// Nostr wire format — [MediaBlobEntity] isn't itself JSON-serializable.
@JsonKey(includeFromJson: false, includeToJson: false) List<MediaBlobEntity> get attachments;
/// Create a copy of NoteEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteEntityCopyWith<NoteEntity> get copyWith => _$NoteEntityCopyWithImpl<NoteEntity>(this as NoteEntity, _$identity);

  /// Serializes this NoteEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.sig, sig) || other.sig == sig)&&(identical(other.authorPubkey, authorPubkey) || other.authorPubkey == authorPubkey)&&(identical(other.content, content) || other.content == content)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.eTagRefs, eTagRefs)&&const DeepCollectionEquality().equals(other.pTagRefs, pTagRefs)&&const DeepCollectionEquality().equals(other.tTags, tTags)&&(identical(other.created, created) || other.created == created)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.rootEventId, rootEventId) || other.rootEventId == rootEventId)&&(identical(other.replyToEventId, replyToEventId) || other.replyToEventId == replyToEventId)&&(identical(other.cachedReplyCount, cachedReplyCount) || other.cachedReplyCount == cachedReplyCount)&&(identical(other.referenceCount, referenceCount) || other.referenceCount == referenceCount)&&(identical(other.sourceGroupId, sourceGroupId) || other.sourceGroupId == sourceGroupId)&&(identical(other.sourcePrivateGroupId, sourcePrivateGroupId) || other.sourcePrivateGroupId == sourcePrivateGroupId)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.embeddedNoteJson, embeddedNoteJson) || other.embeddedNoteJson == embeddedNoteJson)&&(identical(other.quotedNote, quotedNote) || other.quotedNote == quotedNote)&&const DeepCollectionEquality().equals(other.attachments, attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,sig,authorPubkey,content,subject,kind,type,const DeepCollectionEquality().hash(eTagRefs),const DeepCollectionEquality().hash(pTagRefs),const DeepCollectionEquality().hash(tTags),created,conversationId,rootEventId,replyToEventId,cachedReplyCount,referenceCount,sourceGroupId,sourcePrivateGroupId,sourceLabel,embeddedNoteJson,quotedNote,const DeepCollectionEquality().hash(attachments)]);

@override
String toString() {
  return 'NoteEntity(id: $id, sig: $sig, authorPubkey: $authorPubkey, content: $content, subject: $subject, kind: $kind, type: $type, eTagRefs: $eTagRefs, pTagRefs: $pTagRefs, tTags: $tTags, created: $created, conversationId: $conversationId, rootEventId: $rootEventId, replyToEventId: $replyToEventId, cachedReplyCount: $cachedReplyCount, referenceCount: $referenceCount, sourceGroupId: $sourceGroupId, sourcePrivateGroupId: $sourcePrivateGroupId, sourceLabel: $sourceLabel, embeddedNoteJson: $embeddedNoteJson, quotedNote: $quotedNote, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class $NoteEntityCopyWith<$Res>  {
  factory $NoteEntityCopyWith(NoteEntity value, $Res Function(NoteEntity) _then) = _$NoteEntityCopyWithImpl;
@useResult
$Res call({
 String id, String sig, String authorPubkey, String content, String? subject, int kind, NoteType type, List<String> eTagRefs, List<String> pTagRefs, List<String> tTags, DateTime created, int? conversationId, String? rootEventId, String? replyToEventId, int cachedReplyCount, int referenceCount, String? sourceGroupId, String? sourcePrivateGroupId, String? sourceLabel, String? embeddedNoteJson, NoteEntity? quotedNote,@JsonKey(includeFromJson: false, includeToJson: false) List<MediaBlobEntity> attachments
});


$NoteEntityCopyWith<$Res>? get quotedNote;

}
/// @nodoc
class _$NoteEntityCopyWithImpl<$Res>
    implements $NoteEntityCopyWith<$Res> {
  _$NoteEntityCopyWithImpl(this._self, this._then);

  final NoteEntity _self;
  final $Res Function(NoteEntity) _then;

/// Create a copy of NoteEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sig = null,Object? authorPubkey = null,Object? content = null,Object? subject = freezed,Object? kind = null,Object? type = null,Object? eTagRefs = null,Object? pTagRefs = null,Object? tTags = null,Object? created = null,Object? conversationId = freezed,Object? rootEventId = freezed,Object? replyToEventId = freezed,Object? cachedReplyCount = null,Object? referenceCount = null,Object? sourceGroupId = freezed,Object? sourcePrivateGroupId = freezed,Object? sourceLabel = freezed,Object? embeddedNoteJson = freezed,Object? quotedNote = freezed,Object? attachments = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sig: null == sig ? _self.sig : sig // ignore: cast_nullable_to_non_nullable
as String,authorPubkey: null == authorPubkey ? _self.authorPubkey : authorPubkey // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,subject: freezed == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NoteType,eTagRefs: null == eTagRefs ? _self.eTagRefs : eTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,pTagRefs: null == pTagRefs ? _self.pTagRefs : pTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,tTags: null == tTags ? _self.tTags : tTags // ignore: cast_nullable_to_non_nullable
as List<String>,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as DateTime,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as int?,rootEventId: freezed == rootEventId ? _self.rootEventId : rootEventId // ignore: cast_nullable_to_non_nullable
as String?,replyToEventId: freezed == replyToEventId ? _self.replyToEventId : replyToEventId // ignore: cast_nullable_to_non_nullable
as String?,cachedReplyCount: null == cachedReplyCount ? _self.cachedReplyCount : cachedReplyCount // ignore: cast_nullable_to_non_nullable
as int,referenceCount: null == referenceCount ? _self.referenceCount : referenceCount // ignore: cast_nullable_to_non_nullable
as int,sourceGroupId: freezed == sourceGroupId ? _self.sourceGroupId : sourceGroupId // ignore: cast_nullable_to_non_nullable
as String?,sourcePrivateGroupId: freezed == sourcePrivateGroupId ? _self.sourcePrivateGroupId : sourcePrivateGroupId // ignore: cast_nullable_to_non_nullable
as String?,sourceLabel: freezed == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String?,embeddedNoteJson: freezed == embeddedNoteJson ? _self.embeddedNoteJson : embeddedNoteJson // ignore: cast_nullable_to_non_nullable
as String?,quotedNote: freezed == quotedNote ? _self.quotedNote : quotedNote // ignore: cast_nullable_to_non_nullable
as NoteEntity?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MediaBlobEntity>,
  ));
}
/// Create a copy of NoteEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NoteEntityCopyWith<$Res>? get quotedNote {
    if (_self.quotedNote == null) {
    return null;
  }

  return $NoteEntityCopyWith<$Res>(_self.quotedNote!, (value) {
    return _then(_self.copyWith(quotedNote: value));
  });
}
}


/// Adds pattern-matching-related methods to [NoteEntity].
extension NoteEntityPatterns on NoteEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NoteEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NoteEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NoteEntity value)  $default,){
final _that = this;
switch (_that) {
case _NoteEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NoteEntity value)?  $default,){
final _that = this;
switch (_that) {
case _NoteEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String sig,  String authorPubkey,  String content,  String? subject,  int kind,  NoteType type,  List<String> eTagRefs,  List<String> pTagRefs,  List<String> tTags,  DateTime created,  int? conversationId,  String? rootEventId,  String? replyToEventId,  int cachedReplyCount,  int referenceCount,  String? sourceGroupId,  String? sourcePrivateGroupId,  String? sourceLabel,  String? embeddedNoteJson,  NoteEntity? quotedNote, @JsonKey(includeFromJson: false, includeToJson: false)  List<MediaBlobEntity> attachments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NoteEntity() when $default != null:
return $default(_that.id,_that.sig,_that.authorPubkey,_that.content,_that.subject,_that.kind,_that.type,_that.eTagRefs,_that.pTagRefs,_that.tTags,_that.created,_that.conversationId,_that.rootEventId,_that.replyToEventId,_that.cachedReplyCount,_that.referenceCount,_that.sourceGroupId,_that.sourcePrivateGroupId,_that.sourceLabel,_that.embeddedNoteJson,_that.quotedNote,_that.attachments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String sig,  String authorPubkey,  String content,  String? subject,  int kind,  NoteType type,  List<String> eTagRefs,  List<String> pTagRefs,  List<String> tTags,  DateTime created,  int? conversationId,  String? rootEventId,  String? replyToEventId,  int cachedReplyCount,  int referenceCount,  String? sourceGroupId,  String? sourcePrivateGroupId,  String? sourceLabel,  String? embeddedNoteJson,  NoteEntity? quotedNote, @JsonKey(includeFromJson: false, includeToJson: false)  List<MediaBlobEntity> attachments)  $default,) {final _that = this;
switch (_that) {
case _NoteEntity():
return $default(_that.id,_that.sig,_that.authorPubkey,_that.content,_that.subject,_that.kind,_that.type,_that.eTagRefs,_that.pTagRefs,_that.tTags,_that.created,_that.conversationId,_that.rootEventId,_that.replyToEventId,_that.cachedReplyCount,_that.referenceCount,_that.sourceGroupId,_that.sourcePrivateGroupId,_that.sourceLabel,_that.embeddedNoteJson,_that.quotedNote,_that.attachments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String sig,  String authorPubkey,  String content,  String? subject,  int kind,  NoteType type,  List<String> eTagRefs,  List<String> pTagRefs,  List<String> tTags,  DateTime created,  int? conversationId,  String? rootEventId,  String? replyToEventId,  int cachedReplyCount,  int referenceCount,  String? sourceGroupId,  String? sourcePrivateGroupId,  String? sourceLabel,  String? embeddedNoteJson,  NoteEntity? quotedNote, @JsonKey(includeFromJson: false, includeToJson: false)  List<MediaBlobEntity> attachments)?  $default,) {final _that = this;
switch (_that) {
case _NoteEntity() when $default != null:
return $default(_that.id,_that.sig,_that.authorPubkey,_that.content,_that.subject,_that.kind,_that.type,_that.eTagRefs,_that.pTagRefs,_that.tTags,_that.created,_that.conversationId,_that.rootEventId,_that.replyToEventId,_that.cachedReplyCount,_that.referenceCount,_that.sourceGroupId,_that.sourcePrivateGroupId,_that.sourceLabel,_that.embeddedNoteJson,_that.quotedNote,_that.attachments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NoteEntity extends NoteEntity {
  const _NoteEntity({required this.id, required this.sig, required this.authorPubkey, required this.content, this.subject, this.kind = 1, required this.type, required final  List<String> eTagRefs, required final  List<String> pTagRefs, required final  List<String> tTags, required this.created, this.conversationId, this.rootEventId, this.replyToEventId, this.cachedReplyCount = 0, this.referenceCount = 0, this.sourceGroupId, this.sourcePrivateGroupId, this.sourceLabel, this.embeddedNoteJson, this.quotedNote, @JsonKey(includeFromJson: false, includeToJson: false) final  List<MediaBlobEntity> attachments = const []}): _eTagRefs = eTagRefs,_pTagRefs = pTagRefs,_tTags = tTags,_attachments = attachments,super._();
  factory _NoteEntity.fromJson(Map<String, dynamic> json) => _$NoteEntityFromJson(json);

@override final  String id;
@override final  String sig;
@override final  String authorPubkey;
@override final  String content;
@override final  String? subject;
/// Nostr event kind: 1 feed note, 42 group message, 14/15 DM,
/// 9023 private group message. Stored discriminator of the unified Note
/// collection. Note *roles* (reply/root/reference) are still derived from
/// rootEventId/replyToEventId, not from kind.
@override@JsonKey() final  int kind;
@override final  NoteType type;
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

@override final  DateTime created;
/// DM conversation id — non-null only when [kind] is 14/15. Used to route
/// replies back to the correct DM conversation.
@override final  int? conversationId;
/// NIP-10 "root" marker — null means this IS a top-level note.
@override final  String? rootEventId;
/// NIP-10 "reply" marker — the direct parent note this replies to.
@override final  String? replyToEventId;
/// Incoming reply count — notes that reference this one. From the edge table.
@override@JsonKey() final  int cachedReplyCount;
/// Outgoing reference count — notes this one references. From the edge table.
@override@JsonKey() final  int referenceCount;
/// Non-null when this entity was projected from a Kind-42 public group
/// message — used by the Vishnu feed to route taps to the group page
/// instead of the regular thread page. Null for native Kind-1 notes.
@override final  String? sourceGroupId;
/// Non-null when this entity was projected from a NIP-29 private group
/// message. Mutually exclusive with [sourceGroupId].
@override final  String? sourcePrivateGroupId;
/// Pre-rendered chip text shown next to the timestamp on the NoteCard:
///   - `#<name>`  for public group messages
///   - `🔒 <name>` for private group messages
///   - `null`     for native Kind-1 Vishnu notes
/// Resolved by [FeedRepository] at query time from the group/group rows.
@override final  String? sourceLabel;
/// Raw self-contained snapshot of the embedded original (the
/// `embeddedNoteJson` tag / MLS envelope key `"em"`). Source of truth for
/// [quotedNote]; null when this note quotes nothing. A blanked `sig` inside
/// it means the embed failed signature verification (see EmbeddedNoteCodec).
@override final  String? embeddedNoteJson;
/// Pre-resolved one level deep ([quotedNote.quotedNote] is always null).
/// Built from [embeddedNoteJson] (self-contained, retention-immune). Its
/// `sig` is empty when the embed is unverified — the renderer badges it.
@override final  NoteEntity? quotedNote;
/// Pre-resolved attachments. Populated by the data layer when a note is
/// projected from Isar (mirrors how [quotedNote] and [cachedReplyCount]
/// are resolved at query time). UI cards read this directly — no per-
/// card DB lookup.
///
/// Excluded from JSON: this is an in-memory enrichment, not part of the
/// Nostr wire format — [MediaBlobEntity] isn't itself JSON-serializable.
 final  List<MediaBlobEntity> _attachments;
/// Pre-resolved attachments. Populated by the data layer when a note is
/// projected from Isar (mirrors how [quotedNote] and [cachedReplyCount]
/// are resolved at query time). UI cards read this directly — no per-
/// card DB lookup.
///
/// Excluded from JSON: this is an in-memory enrichment, not part of the
/// Nostr wire format — [MediaBlobEntity] isn't itself JSON-serializable.
@override@JsonKey(includeFromJson: false, includeToJson: false) List<MediaBlobEntity> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}


/// Create a copy of NoteEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NoteEntityCopyWith<_NoteEntity> get copyWith => __$NoteEntityCopyWithImpl<_NoteEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NoteEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NoteEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.sig, sig) || other.sig == sig)&&(identical(other.authorPubkey, authorPubkey) || other.authorPubkey == authorPubkey)&&(identical(other.content, content) || other.content == content)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._eTagRefs, _eTagRefs)&&const DeepCollectionEquality().equals(other._pTagRefs, _pTagRefs)&&const DeepCollectionEquality().equals(other._tTags, _tTags)&&(identical(other.created, created) || other.created == created)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.rootEventId, rootEventId) || other.rootEventId == rootEventId)&&(identical(other.replyToEventId, replyToEventId) || other.replyToEventId == replyToEventId)&&(identical(other.cachedReplyCount, cachedReplyCount) || other.cachedReplyCount == cachedReplyCount)&&(identical(other.referenceCount, referenceCount) || other.referenceCount == referenceCount)&&(identical(other.sourceGroupId, sourceGroupId) || other.sourceGroupId == sourceGroupId)&&(identical(other.sourcePrivateGroupId, sourcePrivateGroupId) || other.sourcePrivateGroupId == sourcePrivateGroupId)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.embeddedNoteJson, embeddedNoteJson) || other.embeddedNoteJson == embeddedNoteJson)&&(identical(other.quotedNote, quotedNote) || other.quotedNote == quotedNote)&&const DeepCollectionEquality().equals(other._attachments, _attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,sig,authorPubkey,content,subject,kind,type,const DeepCollectionEquality().hash(_eTagRefs),const DeepCollectionEquality().hash(_pTagRefs),const DeepCollectionEquality().hash(_tTags),created,conversationId,rootEventId,replyToEventId,cachedReplyCount,referenceCount,sourceGroupId,sourcePrivateGroupId,sourceLabel,embeddedNoteJson,quotedNote,const DeepCollectionEquality().hash(_attachments)]);

@override
String toString() {
  return 'NoteEntity(id: $id, sig: $sig, authorPubkey: $authorPubkey, content: $content, subject: $subject, kind: $kind, type: $type, eTagRefs: $eTagRefs, pTagRefs: $pTagRefs, tTags: $tTags, created: $created, conversationId: $conversationId, rootEventId: $rootEventId, replyToEventId: $replyToEventId, cachedReplyCount: $cachedReplyCount, referenceCount: $referenceCount, sourceGroupId: $sourceGroupId, sourcePrivateGroupId: $sourcePrivateGroupId, sourceLabel: $sourceLabel, embeddedNoteJson: $embeddedNoteJson, quotedNote: $quotedNote, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class _$NoteEntityCopyWith<$Res> implements $NoteEntityCopyWith<$Res> {
  factory _$NoteEntityCopyWith(_NoteEntity value, $Res Function(_NoteEntity) _then) = __$NoteEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String sig, String authorPubkey, String content, String? subject, int kind, NoteType type, List<String> eTagRefs, List<String> pTagRefs, List<String> tTags, DateTime created, int? conversationId, String? rootEventId, String? replyToEventId, int cachedReplyCount, int referenceCount, String? sourceGroupId, String? sourcePrivateGroupId, String? sourceLabel, String? embeddedNoteJson, NoteEntity? quotedNote,@JsonKey(includeFromJson: false, includeToJson: false) List<MediaBlobEntity> attachments
});


@override $NoteEntityCopyWith<$Res>? get quotedNote;

}
/// @nodoc
class __$NoteEntityCopyWithImpl<$Res>
    implements _$NoteEntityCopyWith<$Res> {
  __$NoteEntityCopyWithImpl(this._self, this._then);

  final _NoteEntity _self;
  final $Res Function(_NoteEntity) _then;

/// Create a copy of NoteEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sig = null,Object? authorPubkey = null,Object? content = null,Object? subject = freezed,Object? kind = null,Object? type = null,Object? eTagRefs = null,Object? pTagRefs = null,Object? tTags = null,Object? created = null,Object? conversationId = freezed,Object? rootEventId = freezed,Object? replyToEventId = freezed,Object? cachedReplyCount = null,Object? referenceCount = null,Object? sourceGroupId = freezed,Object? sourcePrivateGroupId = freezed,Object? sourceLabel = freezed,Object? embeddedNoteJson = freezed,Object? quotedNote = freezed,Object? attachments = null,}) {
  return _then(_NoteEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sig: null == sig ? _self.sig : sig // ignore: cast_nullable_to_non_nullable
as String,authorPubkey: null == authorPubkey ? _self.authorPubkey : authorPubkey // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,subject: freezed == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NoteType,eTagRefs: null == eTagRefs ? _self._eTagRefs : eTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,pTagRefs: null == pTagRefs ? _self._pTagRefs : pTagRefs // ignore: cast_nullable_to_non_nullable
as List<String>,tTags: null == tTags ? _self._tTags : tTags // ignore: cast_nullable_to_non_nullable
as List<String>,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as DateTime,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as int?,rootEventId: freezed == rootEventId ? _self.rootEventId : rootEventId // ignore: cast_nullable_to_non_nullable
as String?,replyToEventId: freezed == replyToEventId ? _self.replyToEventId : replyToEventId // ignore: cast_nullable_to_non_nullable
as String?,cachedReplyCount: null == cachedReplyCount ? _self.cachedReplyCount : cachedReplyCount // ignore: cast_nullable_to_non_nullable
as int,referenceCount: null == referenceCount ? _self.referenceCount : referenceCount // ignore: cast_nullable_to_non_nullable
as int,sourceGroupId: freezed == sourceGroupId ? _self.sourceGroupId : sourceGroupId // ignore: cast_nullable_to_non_nullable
as String?,sourcePrivateGroupId: freezed == sourcePrivateGroupId ? _self.sourcePrivateGroupId : sourcePrivateGroupId // ignore: cast_nullable_to_non_nullable
as String?,sourceLabel: freezed == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String?,embeddedNoteJson: freezed == embeddedNoteJson ? _self.embeddedNoteJson : embeddedNoteJson // ignore: cast_nullable_to_non_nullable
as String?,quotedNote: freezed == quotedNote ? _self.quotedNote : quotedNote // ignore: cast_nullable_to_non_nullable
as NoteEntity?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MediaBlobEntity>,
  ));
}

/// Create a copy of NoteEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NoteEntityCopyWith<$Res>? get quotedNote {
    if (_self.quotedNote == null) {
    return null;
  }

  return $NoteEntityCopyWith<$Res>(_self.quotedNote!, (value) {
    return _then(_self.copyWith(quotedNote: value));
  });
}
}

// dart format on
