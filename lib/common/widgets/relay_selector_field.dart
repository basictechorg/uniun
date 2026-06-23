import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Reusable relay multi-select with an inline "Add new relay" action.
///
/// Used by Create Channel, Create Private Channel, Create DM and any other
/// surface where the user must pick which relays to publish on. Loads the
/// device's relay list on first build and refreshes after a new relay is
/// added (saved through [SaveRelayUseCase] so the entry persists for next
/// time).
class RelaySelectorField extends StatefulWidget {
  const RelaySelectorField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  /// Optional override for the empty-state placeholder. Defaults to the
  /// localized "Select Relays" string.
  final String? label;

  @override
  State<RelaySelectorField> createState() => _RelaySelectorFieldState();
}

class _RelaySelectorFieldState extends State<RelaySelectorField> {
  List<String> _available = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await getIt<GetRelaysUseCase>().call();
    if (!mounted) return;
    setState(() {
      _available = result.fold(
        (_) => const <String>[],
        (list) => list.map((r) => r.url).toList(),
      );
      _loading = false;
    });
    // Auto-select the UNIUN backend relay when the user hasn't picked any yet,
    // so publishing works out of the box without hand-picking a relay.
    if (widget.selected.isEmpty &&
        _available.contains(AppConstants.kUniunBackend)) {
      widget.onChanged([AppConstants.kUniunBackend]);
    }
  }

  Future<void> _showAddRelayDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(l10n.relayAddDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: l10n.relayAddDialogHint,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.relayAddDialogAction,
                style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    final result = await getIt<SaveRelayUseCase>().call(url);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.relayAddDialogError(f.toString()))),
      ),
      (_) {
        _load();
        if (!widget.selected.contains(url)) {
          widget.onChanged([...widget.selected, url]);
        }
      },
    );
  }

  void _openPicker() {
    final l10n = AppLocalizations.of(context)!;
    final selected = [...widget.selected];
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerLowest,
              title: Row(
                children: [
                  Expanded(child: Text(l10n.relaySelectorPickerTitle)),
                  IconButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _showAddRelayDialog();
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.primary),
                    tooltip: l10n.relaySelectorAddTooltip,
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _available.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.relaySelectorEmpty,
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _available.length,
                        itemBuilder: (_, i) {
                          final relay = _available[i];
                          final isSelected = selected.contains(relay);
                          return CheckboxListTile(
                            activeColor: AppColors.primary,
                            title: Text(relay,
                                style: const TextStyle(fontSize: 14)),
                            value: isSelected,
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  if (!selected.contains(relay)) {
                                    selected.add(relay);
                                  }
                                } else {
                                  selected.remove(relay);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    widget.onChanged(selected);
                    Navigator.pop(ctx);
                  },
                  child: Text(l10n.actionDone,
                      style: const TextStyle(color: AppColors.primary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final placeholder = widget.label ?? l10n.relaySelectorPlaceholder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading)
          const Center(child: DropLoadingIndicator())
        else
          InkWell(
            onTap: _openPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selected.isEmpty
                          ? placeholder
                          : l10n.relaySelectorSelected(widget.selected.length),
                      style: TextStyle(
                        color: widget.selected.isEmpty
                            ? AppColors.onSurfaceVariant
                            : AppColors.onSurface,
                        fontWeight: widget.selected.isEmpty
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded,
                      color: AppColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selected
                  .map(
                    (r) => Chip(
                      label: Text(r, style: const TextStyle(fontSize: 11)),
                      onDeleted: () {
                        final next = [...widget.selected]..remove(r);
                        widget.onChanged(next);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
