import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/shiv/shiv_message_entity.dart';

class BranchTreeGraph extends StatefulWidget {
  const BranchTreeGraph({
    super.key,
    required this.allMessages,
    required this.activeLeafMessageId,
    required this.selectedNodeMessageId,
    required this.onNodeTap,
  });

  final List<ShivMessageEntity> allMessages;
  final String? activeLeafMessageId;
  final String? selectedNodeMessageId;
  final ValueChanged<String> onNodeTap;

  @override
  State<BranchTreeGraph> createState() => _BranchTreeGraphState();
}

class _BranchTreeGraphState extends State<BranchTreeGraph> {
  late Graph _graph;
  late BuchheimWalkerConfiguration _config;
  late BuchheimWalkerAlgorithm _algorithm;
  late Set<String> _activeBranchIds;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(BranchTreeGraph old) {
    super.didUpdateWidget(old);
    if (old.allMessages != widget.allMessages ||
        old.activeLeafMessageId != widget.activeLeafMessageId) {
      _buildGraph();
    }
  }

  void _buildGraph() {
    _graph = Graph()..isTree = true;
    _config = BuchheimWalkerConfiguration()
      ..siblingSeparation = 32
      ..levelSeparation = 70
      ..subtreeSeparation = 40
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
    _algorithm = BuchheimWalkerAlgorithm(_config, TreeEdgeRenderer(_config));
    _activeBranchIds = _buildActiveBranchIds();

    final nodeMap = <String, Node>{};
    for (final msg in widget.allMessages) {
      nodeMap[msg.messageId] = Node.Id(msg.messageId);
    }

    for (final msg in widget.allMessages) {
      if (msg.parentId != null && nodeMap.containsKey(msg.parentId)) {
        _graph.addEdge(nodeMap[msg.parentId]!, nodeMap[msg.messageId]!);
      }
    }

    // Ensure root nodes are added even without edges
    final allIds = widget.allMessages.map((m) => m.messageId).toSet();
    for (final msg in widget.allMessages) {
      if (msg.parentId == null || !allIds.contains(msg.parentId)) {
        if (!_graph.nodes.contains(nodeMap[msg.messageId])) {
          _graph.addNode(nodeMap[msg.messageId]!);
        }
      }
    }
  }

  Set<String> _buildActiveBranchIds() {
    final ids = <String>{};
    final byId = {for (final m in widget.allMessages) m.messageId: m};
    String? current = widget.activeLeafMessageId;
    while (current != null) {
      ids.add(current);
      current = byId[current]?.parentId;
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allMessages.isEmpty) return const SizedBox.shrink();

    final msgById = {for (final m in widget.allMessages) m.messageId: m};

    // InteractiveViewer(constrained: false) inside a bounded parent (Expanded)
    // is the correct graphview pattern. The viewer clips to its parent bounds
    // and the child (GraphView) sizes itself to its content.
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.3,
      maxScale: 2.5,
      child: Padding(
        // Centre the tree with symmetric padding so it starts centred
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: GraphView(
          graph: _graph,
          algorithm: _algorithm,
          paint: Paint()
            ..color = AppColors.outlineVariant
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final msgId = node.key!.value as String;
            final msg = msgById[msgId];
            if (msg == null) return const SizedBox.shrink();

            return GestureDetector(
              onTap: () => widget.onNodeTap(msgId),
              child: _TreeNode(
                message: msg,
                isUser: msg.role.name == 'user',
                isOnActivePath: _activeBranchIds.contains(msgId),
                isSelected: widget.selectedNodeMessageId == msgId,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.message,
    required this.isUser,
    required this.isOnActivePath,
    required this.isSelected,
  });

  final ShivMessageEntity message;
  final bool isUser;
  final bool isOnActivePath;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final preview = message.content.isEmpty
        ? '…'
        : message.content.length > 28
            ? '${message.content.substring(0, 28)}…'
            : message.content;

    // Explicit opaque solid colours — never transparent
    final bgColor = isOnActivePath
        ? (isUser
            ? AppColors.surfaceContainerHigh       // grey for user on active path
            : const Color(0xFFEAF1FF))             // light-blue tint for AI on active path
        : AppColors.surfaceContainerLowest;        // solid white for inactive nodes

    final borderColor = isSelected
        ? AppColors.primary
        : isOnActivePath
            ? AppColors.primary.withValues(alpha: 0.45)
            : const Color(0xFFDDE1EA);             // subtle grey border

    return Container(
      constraints: const BoxConstraints(maxWidth: 140, minWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isSelected ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUser ? Icons.person_rounded : Icons.smart_toy_outlined,
            size: 14,
            color: isOnActivePath ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              preview,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isOnActivePath ? FontWeight.w600 : FontWeight.w400,
                color: isOnActivePath
                    ? AppColors.onSurface
                    : AppColors.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
