import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/brahma/graph/models/graph_node_type.dart';

part 'graph_event.dart';
part 'graph_state.dart';

@injectable
class GraphBloc extends Bloc<GraphEvent, GraphState> {
  final GetAllSavedNotesUseCase _getAllSavedNotes;
  final GetOwnNotesUseCase _getOwnNotes;
  final GetDraftsUseCase _getDrafts;
  final GetActiveUserProfileUseCase _getActiveUserProfile;
  final DeleteDraftUseCase _deleteDraft;
  final GetProfileUseCase _getProfile;

  GraphBloc(
    this._getAllSavedNotes,
    this._getOwnNotes,
    this._getDrafts,
    this._getActiveUserProfile,
    this._deleteDraft,
    this._getProfile,
  ) : super(const GraphState()) {
    on<LoadGraphEvent>(_onLoad);
    on<SelectGraphNodeEvent>(_onSelect);
    on<DeselectGraphNodeEvent>(_onDeselect);
    on<DeleteDraftNodeEvent>(_onDeleteDraft);
  }

  Future<void> _onLoad(LoadGraphEvent event, Emitter<GraphState> emit) async {
    emit(state.copyWith(status: GraphStatus.loading));

    // ── 1. Saved notes ────────────────────────────────────────────────────────
    final savedResult = await _getAllSavedNotes.call();
    final savedNotes = savedResult.fold((_) => [], (n) => n);
    final savedIds = {for (final n in savedNotes) n.eventId};

    // ── 2. Own published notes ────────────────────────────────────────────────
    final profileResult = await _getActiveUserProfile.call();
    final pubkeyHex = profileResult.fold((_) => null, (p) => p.pubkeyHex);

    final ownNotes = <GraphNodeData>[];
    if (pubkeyHex != null) {
      final ownResult = await _getOwnNotes.call(pubkeyHex);
      ownResult.fold((_) {}, (notes) {
        for (final n in notes) {
          if (!savedIds.contains(n.id)) {
            ownNotes.add(GraphNodeData(
              eventId: n.id,
              content: n.content,
              eTagRefs: n.eTagRefs,
              type: GraphNodeType.own,
              authorPubkey: n.authorPubkey,
              sig: n.sig,
              created: n.created,
              tTags: n.tTags,
              pTagRefs: n.pTagRefs,
            ));
          }
        }
      });
    }

    // ── 3. Draft notes ────────────────────────────────────────────────────────
    final draftResult = await _getDrafts.call();
    final draftNodes = <GraphNodeData>[];
    draftResult.fold((_) {}, (drafts) {
      for (final d in drafts) {
        draftNodes.add(GraphNodeData(
          eventId: d.draftId,
          content: d.content,
          eTagRefs: d.eTagRefs,
          type: GraphNodeType.draft,
        ));
      }
    });

    // ── 4. Saved → GraphNodeData ──────────────────────────────────────────────
    final savedNodes = savedNotes
        .map((n) => GraphNodeData(
              eventId: n.eventId,
              content: n.content,
              eTagRefs: n.eTagRefs,
              type: GraphNodeType.saved,
              authorPubkey: n.authorPubkey,
              sig: n.sig,
              created: n.created,
              tTags: n.tTags,
              pTagRefs: n.pTagRefs,
            ))
        .toList();

    final allNodes = [...savedNodes, ...ownNotes, ...draftNodes];

    emit(state.copyWith(
      status: GraphStatus.loaded,
      nodes: allNodes,
      adjacency: _buildAdjacency(allNodes),
    ));
  }

  Future<void> _onSelect(
      SelectGraphNodeEvent event, Emitter<GraphState> emit) async {
    if (state.selectedNodeId == event.nodeId) {
      emit(state.copyWith(clearSelection: true));
      return;
    }

    emit(state.copyWith(selectedNodeId: event.nodeId));

    // Lazily load the selected node's author profile — profiles are only
    // needed by the node panel, which only renders on selection.
    final node = state.selectedNode;
    final pubkey = node?.authorPubkey;
    if (pubkey == null || pubkey.isEmpty || state.profiles.containsKey(pubkey)) {
      return;
    }
    final r = await _getProfile.call(pubkey);
    r.fold((_) {}, (p) {
      emit(state.copyWith(profiles: {...state.profiles, p.pubkey: p}));
    });
  }

  void _onDeselect(DeselectGraphNodeEvent event, Emitter<GraphState> emit) {
    emit(state.copyWith(clearSelection: true));
  }

  Future<void> _onDeleteDraft(
      DeleteDraftNodeEvent event, Emitter<GraphState> emit) async {
    await _deleteDraft.call(event.draftId);
    add(const LoadGraphEvent());
  }

  static Map<String, Set<String>> _buildAdjacency(List<GraphNodeData> nodes) {
    final allIds = {for (final n in nodes) n.eventId};
    final adj = <String, Set<String>>{
      for (final n in nodes) n.eventId: <String>{},
    };
    for (final node in nodes) {
      for (final ref in node.eTagRefs) {
        if (ref != node.eventId && allIds.contains(ref)) {
          adj[node.eventId]!.add(ref);
          adj[ref]!.add(node.eventId);
        }
      }
    }
    return adj;
  }
}
