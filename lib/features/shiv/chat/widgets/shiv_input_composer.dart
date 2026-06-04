import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_model_picker_sheet.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Bottom input bar.
/// Sits inside a Scaffold with resizeToAvoidBottomInset: true — the scaffold
/// handles keyboard avoidance. We only add safe-area bottom padding (home bar).
class ShivInputComposer extends StatefulWidget {
  const ShivInputComposer({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.isStreaming,
  });

  final void Function(String text) onSend;
  final VoidCallback onStop;
  final bool isStreaming;

  @override
  State<ShivInputComposer> createState() => _ShivInputComposerState();
}

class _ShivInputComposerState extends State<ShivInputComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

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
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.isStreaming;
    final isStreaming = widget.isStreaming;
    final l10n = AppLocalizations.of(context)!;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // When keyboard is open: pad by keyboard height + 10px gap so input sits above keyboard.
    // When keyboard is closed: clear the floating nav. The nav's height grows by
    // the home-indicator safe area, so add that inset too — otherwise the input
    // collides with the nav on devices with a home indicator.
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = keyboardHeight > 0 ? keyboardHeight + 10.0 : 80.0 + safeBottom;

    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: canSend
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.outlineVariant,
            width: canSend ? 1 : 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // + icon → opens the model picker sheet. Disabled while
            // streaming so the user can't swap the model mid-turn (would
            // be ambiguous about which model owns the response).
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
              child: Tooltip(
                message: l10n.chatInputPickModelTooltip,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: isStreaming
                      ? null
                      : () => showModelPickerSheet(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: isStreaming
                          ? AppColors.outline
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: l10n.shivInputHint,
                  hintStyle: const TextStyle(
                    color: AppColors.outline,
                    fontSize: 15,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            // Send / Stop button — swaps while streaming so the user can
            // interrupt long responses.
            Padding(
              padding: const EdgeInsets.all(6),
              child: GestureDetector(
                onTap: isStreaming
                    ? widget.onStop
                    : (canSend ? _submit : null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isStreaming || canSend
                        ? AppColors.primary
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: (isStreaming || canSend)
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    isStreaming
                        ? Icons.stop_rounded
                        : Icons.send_rounded,
                    size: isStreaming ? 20 : 18,
                    color: (isStreaming || canSend)
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
