import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';

part 'saved_note_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('SavedNote')
class SavedNoteModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  late String sig;
  late String authorPubkey;
  late String content;

  @Enumerated(EnumType.name)
  late NoteType type;

  late List<String> eTagRefs;

  @Index()
  String? rootEventId;

  @Index()
  String? replyToEventId;

  late List<String> pTagRefs;
  late List<String> tTags;

  late DateTime created;

  @Index()
  late DateTime savedAt;

  /// Source channel id if this saved item was originally a Kind-42 public
  /// channel message. Used by the saved-notes UI to render the "#channel"
  /// chip and to route taps to the channel thread page.
  String? sourceChannelId;

  /// Source group id if this saved item was a NIP-29 private channel message.
  /// Mutually exclusive with [sourceChannelId].
  String? sourcePrivateGroupId;

  /// NIP-18 `q` tag. The quoted note is NOT saved-forever — read-time lookup
  /// against the live `Note` collection; misses render as not-available.
  @Index()
  String? quoteEventId;
}

extension SavedNoteModelExtension on SavedNoteModel {
  SavedNoteEntity toDomain() => SavedNoteEntity(
        eventId: eventId,
        sig: sig,
        authorPubkey: authorPubkey,
        content: content,
        type: type,
        eTagRefs: eTagRefs,
        pTagRefs: pTagRefs,
        tTags: tTags,
        created: created,
        savedAt: savedAt,
        sourceChannelId: sourceChannelId,
        sourcePrivateGroupId: sourcePrivateGroupId,
        quoteEventId: quoteEventId,
      );
}
