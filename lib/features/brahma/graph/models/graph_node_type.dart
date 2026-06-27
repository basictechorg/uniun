import 'package:uniun/core/notes/reply_edge.dart';
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
    this.rootEventId,
    this.replyToEventId,
    this.referenceCount = 0,
    this.cachedReplyCount = 0,
    this.tTags = const [],
    this.pTagRefs = const [],
    this.attachments = const [],
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

  /// NIP-10 threading markers — drive [refEdges] so the graph excludes the
  /// thread root from edges (a deep reply links to its direct parent only,
  /// never to the root). Null for top-level notes / unmarked drafts.
  final String? rootEventId;
  final String? replyToEventId;

  /// Enriched edge-table counts (own/saved nodes only — drafts stay 0).
  /// Outgoing references this note makes / incoming references to it. Carried
  /// so the node panel's NoteCard shows the real counts instead of zeros.
  final int referenceCount;
  final int cachedReplyCount;

  /// NIP-92 media attachments resolved by the data layer. Empty for draft
  /// nodes that haven't been enriched.
  final List<MediaBlobEntity> attachments;

  /// Copy with the global edge-table counts applied. The graph shows global
  /// (not saved-scoped) counts so a node's comment count includes every note
  /// that references it — saved or not.
  GraphNodeData withCounts({
    required int referenceCount,
    required int cachedReplyCount,
  }) =>
      GraphNodeData(
        eventId: eventId,
        content: content,
        eTagRefs: eTagRefs,
        type: type,
        authorPubkey: authorPubkey,
        sig: sig,
        created: created,
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        referenceCount: referenceCount,
        cachedReplyCount: cachedReplyCount,
        tTags: tTags,
        pTagRefs: pTagRefs,
        attachments: attachments,
      );

  /// The note ids this node draws a graph edge to: the canonical
  /// reference/reply parents (NIP-10 root marker excluded — same rule as
  /// [replyEdgeParentIds] that backs the reference/comment counts), so a graph
  /// edge is exactly one comment↔reference pair and the thread root never
  /// becomes a hub of its descendant replies.
  Set<String> get refEdges => replyEdgeParentIds(
        replyToEventId: replyToEventId,
        rootEventId: rootEventId,
        eTagRefs: eTagRefs,
      );
}
