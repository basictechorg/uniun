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
/// Used by Create Group, Create Private Group, Create DM and any other
/// surface where the user must pick which relays to publish on. Loads the
/// device's relay list on first build and refreshes after a new relay is
/// added (saved through [SaveRelayUseCase] so the entry persists for next
/// time).
///
/// Selection is presented as a tappable field that opens a bottom sheet of
/// checkable relay rows with an inline add field — matching the relay picker
/// on the Join Group screen.
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
  final _relayUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _relayUrlController.dispose();
    super.dispose();
  }

  Future<List<String>> _fetchAvailable() async {
    final result = await getIt<GetRelaysUseCase>().call();
    return result.fold(
      (_) => const <String>[],
      (list) => list.map((r) => r.url).toList(),
    );
  }

  Future<void> _load() async {
    final available = await _fetchAvailable();
    if (!mounted) return;
    setState(() {
      _available = available;
      _loading = false;
    });
    // Auto-select the UNIUN backend relay when the user hasn't picked any yet,
    // so publishing works out of the box without hand-picking a relay.
    if (widget.selected.isEmpty &&
        _available.contains(AppConstants.kUniunBackend)) {
      widget.onChanged([AppConstants.kUniunBackend]);
    }
  }

  // Relay multi-select as a bottom sheet: tap a row to (de)select, add a new
  // relay inline, Done to close. Selection lives in [widget.selected] and a new
  // relay is persisted through [SaveRelayUseCase].
  void _openSheet() {
    final l10n = AppLocalizations.of(context)!;
    final localSelected = [...widget.selected];
    _relayUrlController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            void toggle(String relay, bool selected) {
              if (selected) {
                if (!localSelected.contains(relay)) localSelected.add(relay);
              } else {
                localSelected.remove(relay);
              }
              widget.onChanged([...localSelected]);
              setSheet(() {});
            }

            Future<void> addRelay() async {
              final url = _relayUrlController.text.trim();
              if (url.isEmpty) return;
              final result = await getIt<SaveRelayUseCase>().call(url);
              if (!mounted) return;
              result.fold(
                (f) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.relayAddDialogError(f.toString()))),
                ),
                (_) async {
                  final next = await _fetchAvailable();
                  if (!mounted) return;
                  setState(() => _available = next);
                  _relayUrlController.clear();
                  if (!localSelected.contains(url)) {
                    localSelected.add(url);
                    widget.onChanged([...localSelected]);
                  }
                  setSheet(() {});
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.relaySelectorPickerTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: _available.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  l10n.relaySelectorEmpty,
                                  style:
                                      const TextStyle(color: AppColors.outline),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _available.length,
                              itemBuilder: (_, i) {
                                final relay = _available[i];
                                final selected = localSelected.contains(relay);
                                return _RelaySheetRow(
                                  url: relay,
                                  selected: selected,
                                  onTap: () => toggle(relay, !selected),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    // Inline add — no nested dialog.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _relayUrlController,
                              keyboardType: TextInputType.url,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: AppColors.onSurface,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: l10n.relayAddDialogHint,
                                hintStyle: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: AppColors.outline,
                                ),
                                prefixIcon: const Icon(Icons.add_rounded,
                                    size: 20, color: AppColors.primary),
                              ),
                              onSubmitted: (_) => addRelay(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: addRelay,
                            child: Text(
                              l10n.relayAddDialogAction,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            l10n.actionDone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            onTap: _openSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.dns_rounded,
                      size: 20, color: AppColors.outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.selected.isEmpty
                          ? placeholder
                          : l10n.relaySelectorSelected(widget.selected.length),
                      style: TextStyle(
                        color: widget.selected.isEmpty
                            ? AppColors.outline
                            : AppColors.onSurface,
                        fontWeight: widget.selected.isEmpty
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded,
                      color: AppColors.outline),
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
                    (r) => _RelayTag(
                      url: r,
                      onRemove: () {
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

/// A single checkable relay row inside the picker sheet.
class _RelaySheetRow extends StatelessWidget {
  const _RelaySheetRow({
    required this.url,
    required this.selected,
    required this.onTap,
  });

  final String url;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.dns_rounded,
              size: 18,
              color: selected ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: selected
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: selected ? AppColors.primary : AppColors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// A selected-relay tag: a tonal pill (DS chip tint wash) carrying the relay
/// url in mono with a tap-to-remove ×.
class _RelayTag extends StatelessWidget {
  const _RelayTag({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            url,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
