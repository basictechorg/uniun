import 'dart:async';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/brahma/graph/models/graph_node_type.dart';
import 'package:uniun/features/brahma/utils/manas_colors.dart';

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
  final GetNoteIdsForManasUseCase _getNoteIdsForManas;
  final GetManasByIdUseCase _getManasById;
  final Isar _isar;

  StreamSubscription<void>? _deletedNoteWatcher;

  GraphBloc(
    this._getAllSavedNotes,
    this._getOwnNotes,
    this._getDrafts,
    this._getActiveUserProfile,
    this._deleteDraft,
    this._getProfile,
    this._getNoteIdsForManas,
    this._getManasById,
    this._isar,
  ) : super(const GraphState()) {
    on<LoadGraphEvent>(_onLoad);
    on<SelectGraphNodeEvent>(_onSelect);
    on<DeselectGraphNodeEvent>(_onDeselect);
    on<DeleteDraftNodeEvent>(_onDeleteDraft);

    // Deleting a note tombstones it in deletedNoteModels and removes its
    // NoteModel row. Rebuild the graph so the deleted node disappears —
    // preserve the current Manas scope across the reload.
    _deletedNoteWatcher = _isar.deletedNoteModels.watchLazy().listen((_) {
      if (!isClosed) {
        add(LoadGraphEvent(
          manasId: state.scopedManasId,
          manasName: state.scopedManasName,
        ));
      }
    });
  }

  @override
  Future<void> close() {
    _deletedNoteWatcher?.cancel();
    return super.close();
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
          // DMs (kind 14/15) are authored by this user too, but they are
          // private messages — never surface them in the Brahma graph.
          if (n.kind == kDmTextKind || n.kind == kDmFileKind) continue;
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
              attachments: n.attachments,
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
              attachments: n.attachments,
            ))
        .toList();

    final fullNodes = [...savedNodes, ...ownNotes, ...draftNodes];

    // ── 5. Manas scoping ─────────────────────────────────────────────────────
    // When `event.manasId` is set, restrict the visible node set to that
    // Manas's membership. _buildAdjacency already drops refs that fall
    // outside the live id set, so cross-scope edges disappear naturally.
    //
    // When the Manas also has a chosen palette, paint each node with a
    // stable-hash colour pulled from it via ManasColors.colorFor. This
    // only happens in scoped mode — unscoped Brahma keeps its fixed
    // saved/own/draft colours from app_theme.dart.
    List<GraphNodeData> allNodes = fullNodes;
    String? scopeName = event.manasName;
    List<String> scopePalette = const <String>[];
    String? scopeIcon;
    if (event.manasId != null) {
      final linkRes = await _getNoteIdsForManas.call(event.manasId!);
      final allowed = linkRes
          .fold<Set<String>>((_) => const <String>{}, (l) => l.toSet());
      final manasRes = await _getManasById.call(event.manasId!);
      scopePalette = manasRes.fold(
        (_) => const <String>[],
        (m) => m.colorHexes,
      );
      scopeIcon = manasRes.fold((_) => null, (m) => m.iconName);
      scopeName ??= manasRes.fold((_) => null, (m) => m.name);
      allNodes = [
        for (final n in fullNodes)
          if (allowed.contains(n.eventId))
            scopePalette.isEmpty
                ? n
                : _withColor(n, ManasColors.colorFor(n.eventId, scopePalette)),
      ];
    }

    emit(state.copyWith(
      status: GraphStatus.loaded,
      nodes: allNodes,
      adjacency: _buildAdjacency(allNodes),
      scopedManasId: event.manasId,
      scopedManasName: scopeName,
      scopedManasIconName: scopeIcon,
      scopedManasColorHexes: scopePalette,
      clearScope: event.manasId == null,
    ));
  }

  /// Clones [n] with the given override colour. Cheap — only called on the
  /// scoped (small) subset.
  GraphNodeData _withColor(GraphNodeData n, Color? color) =>
      GraphNodeData(
        eventId: n.eventId,
        content: n.content,
        eTagRefs: n.eTagRefs,
        type: n.type,
        authorPubkey: n.authorPubkey,
        sig: n.sig,
        created: n.created,
        tTags: n.tTags,
        pTagRefs: n.pTagRefs,
        attachments: n.attachments,
        overrideColor: color,
      );

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
    add(LoadGraphEvent(
      manasId: state.scopedManasId,
      manasName: state.scopedManasName,
    ));
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
