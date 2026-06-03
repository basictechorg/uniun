import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';
import 'package:uniun/common/widgets/floating_nav.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/features/brahma/graph/widgets/graph_canvas.dart';
import 'package:uniun/features/brahma/graph/widgets/graph_fab.dart';
import 'package:uniun/features/brahma/graph/widgets/graph_header.dart';
import 'package:uniun/features/brahma/graph/widgets/graph_node_panel.dart';

class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<GraphBloc>()..add(const LoadGraphEvent()),
        ),
        BlocProvider(
          create: (_) =>
              getIt<BrahmaCreateBloc>()..add(const LoadDraftsEvent()),
        ),
      ],
      child: const _GraphView(),
    );
  }
}

class _GraphView extends StatefulWidget {
  const _GraphView();

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> {
  bool _isGraphInteracting = false;
  bool _hasSelectedNode = false;

  bool get _navVisible => !_isGraphInteracting && !_hasSelectedNode;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BrahmaCreateBloc, BrahmaCreateState>(
          listenWhen: (prev, curr) => prev.status != curr.status,
          listener: (context, state) {
            if (state.status == BrahmaCreateStatus.success) {
              // Pop back to the existing Home (Vishnu) instead of goNamed,
              // which would rebuild the whole shell and lose its state. Home
              // is the bottom of this navigator's stack.
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        BlocListener<GraphBloc, GraphState>(
          listenWhen: (prev, curr) =>
              (prev.selectedNode == null) != (curr.selectedNode == null),
          listener: (context, state) {
            final has = state.selectedNode != null;
            if (_hasSelectedNode != has) setState(() => _hasSelectedNode = has);
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            // Positioned.fill gives _GraphBody tight constraints so GraphCanvas
            // LayoutBuilder gets the full screen size (without this, the inner
            // Stack with only Positioned children would have zero size).
            Positioned.fill(
              child: _GraphBody(
                onInteractingChanged: (v) {
                  if (_isGraphInteracting != v) {
                    setState(() => _isGraphInteracting = v);
                  }
                },
              ),
            ),

            // FloatingNav — hides while graph is being touched or node panel is open
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _navVisible ? Offset.zero : const Offset(0, 1.5),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: FloatingNav(
                  currentIndex: 1,
                  onTap: (i) async {
                    if (i == 1) return;
                    Navigator.pop(context, i);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Graph body ─────────────────────────────────────────────────────────────────

class _GraphBody extends StatelessWidget {
  const _GraphBody({required this.onInteractingChanged});
  final ValueChanged<bool> onInteractingChanged;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GraphBloc, GraphState>(
      builder: (context, state) {
        if (state.status == GraphStatus.initial ||
            state.status == GraphStatus.loading) {
          return const Column(
            children: [
              GraphHeader(),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        if (state.status == GraphStatus.error) {
          return Column(
            children: [
              const GraphHeader(),
              Expanded(
                child: Center(
                  child: Text(
                    state.errorMessage ?? 'Failed to load graph',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GraphCanvas(
                nodes: state.nodes,
                adjacency: state.adjacency,
                selectedNodeId: state.selectedNodeId,
                onNodeTap: (id) =>
                    context.read<GraphBloc>().add(SelectGraphNodeEvent(id)),
                onCanvasTap: () =>
                    context.read<GraphBloc>().add(const DeselectGraphNodeEvent()),
                onInteractingChanged: onInteractingChanged,
              ),
            ),

            const Positioned(
              top: 0, left: 0, right: 0,
              child: GraphHeader(),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _NodePanelSlider(state: state),
            ),

            if (state.selectedNode == null)
              Positioned(
                // Clear the floating nav, whose height grows by the
                // home-indicator safe area — add that inset so the FAB
                // doesn't touch the nav on devices with a home indicator.
                right: 20, bottom: 96 + MediaQuery.of(context).padding.bottom,
                child: const GraphFab(),
              ),
          ],
        );
      },
    );
  }
}

// ── Animated panel wrapper ─────────────────────────────────────────────────────
class _NodePanelSlider extends StatelessWidget {
  const _NodePanelSlider({required this.state});
  final GraphState state;

  @override
  Widget build(BuildContext context) {
    final node = state.selectedNode;
    return AnimatedSlide(
      offset: node != null ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: node == null,
        child: node != null
            ? GraphNodePanel(
                node: node,
                profile: node.authorPubkey != null
                    ? state.profiles[node.authorPubkey]
                    : null,
                onClose: () => context
                    .read<GraphBloc>()
                    .add(const DeselectGraphNodeEvent()),
                onEditTap: (draftId) async {
                  final bloc = context.read<GraphBloc>();
                  await context.pushNamed(
                    AppRoutes.brahmaCreate,
                    extra: {'draftId': draftId, 'autoPublish': false},
                  );
                  bloc.add(const LoadGraphEvent());
                  bloc.add(SelectGraphNodeEvent(draftId));
                },
                onPublishTap: (draftId) {
                  // Publish directly — no navigation needed.
                  // BlocListener<BrahmaCreateBloc> in GraphPage handles
                  // popping to home on success.
                  context.read<BrahmaCreateBloc>().add(
                        PublishDraftEvent(
                          draftId: draftId,
                          content: node.content,
                        ),
                      );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
