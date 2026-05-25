import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';

class ChannelReferencePicker extends StatefulWidget {
  const ChannelReferencePicker({
    super.key,
    required this.messages,
    required this.selected,
    required this.onToggle,
  });

  final List<ChannelMessageEntity> messages;
  final List<ChannelMessageEntity> selected;
  final void Function(ChannelMessageEntity) onToggle;

  @override
  State<ChannelReferencePicker> createState() => _ChannelReferencePickerState();
}

class _ChannelReferencePickerState extends State<ChannelReferencePicker> {
  String _query = '';
  late final List<ChannelMessageEntity> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.messages
        : widget.messages
            .where(
              (m) => m.content.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Reference a message',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14, color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Search messages…',
                hintStyle: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Results
          Flexible(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No messages match your search.',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final msg = filtered[i];
                      final isSelected = _selected.any((m) => m.id == msg.id);
                      final preview = msg.content.trim();
                      final label = preview.length > 100
                          ? '${preview.substring(0, 100)}…'
                          : preview.isEmpty
                              ? '…'
                              : preview;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.removeWhere((m) => m.id == msg.id);
                            } else {
                              _selected.add(msg);
                            }
                          });
                          widget.onToggle(msg);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.article_outlined,
                                  size: 16,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Text(
                                  'Selected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
