import 'package:flutter/painting.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

/// Discriminates the three kinds of nodes shown in the knowledge graph.
enum GraphNodeType { saved, own, draft }

/// Lightweight data carrier — used by GraphBloc and GraphCanvas instead of
/// raw domain entities so the canvas doesn't need to know about SavedNoteEntity
/// vs NoteEntity vs DraftEntity.
class GraphNodeData {
  const GraphNodeData({
    required this.eventId,
    required this.content,
    required this.eTagRefs,
    required this.type,
    this.authorPubkey,
    this.sig,
    this.created,
    this.tTags = const [],
    this.pTagRefs = const [],
    this.attachments = const [],
    this.overrideColor,
  });

  /// Unique identifier:
  ///   saved / own → Nostr event ID
  ///   draft       → DraftEntity.draftId
  final String eventId;
  final String content;
  final List<String> eTagRefs;
  final GraphNodeType type;
  final String? authorPubkey;

  /// Extra fields populated for saved/own nodes so the panel can render
  /// a full NoteCard without the bloc importing entity/extension files.
  final String? sig;
  final DateTime? created;
  final List<String> tTags;
  final List<String> pTagRefs;

  /// NIP-92 media attachments resolved by the data layer. Empty for draft
  /// nodes that haven't been enriched.
  final List<MediaBlobEntity> attachments;

  /// Per-node tint override. Non-null only when the graph is scoped to a
  /// Manas with a chosen palette — the canvas painter prefers this over
  /// the type-derived default. Unscoped Brahma always leaves this null.
  final Color? overrideColor;
}
