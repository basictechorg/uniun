import 'package:flutter/material.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_model_picker_sheet.dart';
import 'package:uniun/features/shiv/composer_chat/widgets/manas_picker_sheet.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Shiv chat input bar — same visual language as the Vishnu/thread AI composer
/// (rounded card, text field on top, a control row of circular buttons below):
///   [scope-avatar → Manas picker] [model picker] … [send / stop]
///
/// The scope avatar lets the user ground the chat in a specific Manas (or the
/// whole library); the picked `manasIds` ride each send and scope the RAG.
class ShivInputComposer extends StatefulWidget {
  const ShivInputComposer({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.isStreaming,
  });

  final void Function(String text, List<String> manasIds) onSend;
  final VoidCallback onStop;
  final bool isStreaming;

  @override
  State<ShivInputComposer> createState() => _ShivInputComposerState();
}

class _ShivInputComposerState extends State<ShivInputComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  /// The Manas the chat is grounded in. Defaults to the whole library.
  ManasChatScope _scope = const ManasChatScope(
    manasIds: [],
    icon: kAllNotesIcon,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isStreaming) return;
    _controller.clear();
    widget.onSend(text, _scope.manasIds);
  }

  Future<void> _pickScope() async {
    final scope = await showManasChatPicker(context, current: _scope);
    if (scope == null || !mounted) return;
    setState(() => _scope = scope);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.isStreaming;
    final isStreaming = widget.isStreaming;
    final l10n = AppLocalizations.of(context)!;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    // The Shiv chat is full-screen (no FloatingNav), so the composer only needs
    // to clear the device safe-area — not reserve space for the bottom tab.
    final bottomPad = keyboardHeight > 0
        ? keyboardHeight + 10.0
        : safeBottom + 12.0;
    final scopeLabel = _scope.name ?? 'All notes';

    // Full-width, rounded-top, surfaceContainerLow — same as the Vishnu/thread
    // composer. The card colour matches the global input fill so the text field
    // is seamless with its surround, and there is no side margin.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 10, 12, bottomPad),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: l10n.composerAskScope(_scope.name ?? 'Brahma'),
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 15,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Scope avatar → Manas picker. Shows the picked scope's icon.
              _CircleButton(
                icon: _scope.icon,
                onTap: _pickScope,
                tooltip: 'Grounded in $scopeLabel',
                filled: true,
              ),
              const SizedBox(width: 8),
              // AI model picker. Disabled mid-stream (ambiguous ownership).
              _CircleButton(
                icon: Icons.smart_toy_rounded,
                onTap: isStreaming ? null : () => showModelPickerSheet(context),
                tooltip: l10n.chatInputPickModelTooltip,
              ),
              const Spacer(),
              // Send / Stop — swaps while streaming so the user can interrupt.
              GestureDetector(
                onTap: isStreaming ? widget.onStop : (canSend ? _submit : null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isStreaming || canSend
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isStreaming
                        ? Icons.stop_rounded
                        : Icons.arrow_upward_rounded,
                    size: isStreaming ? 20 : 18,
                    color: (isStreaming || canSend)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular control button matching the Vishnu AI composer's buttons.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Primary-tinted (used for the active scope avatar).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? Theme.of(context).colorScheme.outline
        : (filled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant);
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
