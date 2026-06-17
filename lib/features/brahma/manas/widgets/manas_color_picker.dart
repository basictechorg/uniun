import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/brahma/utils/manas_colors.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Modal grid that lets the user pick 1–3 colors for a Manas. Returns the
/// selected list of hex strings (in pick order), or null on dismiss. An
/// empty selection collapses to null too — caller treats that as "use the
/// default saved-blue."
class ManasColorPicker {
  static Future<List<String>?> show(BuildContext context,
      {required List<String> current}) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PickerBody(initial: current),
    );
  }
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({required this.initial});
  final List<String> initial;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  static const int _maxPicks = 3;
  late List<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = [...widget.initial];
  }

  void _toggle(String hex) {
    setState(() {
      if (_picked.contains(hex)) {
        _picked.remove(hex);
      } else if (_picked.length < _maxPicks) {
        _picked.add(hex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.palette_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.manasColorPickerTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.manasColorPickerSubtitle(_picked.length),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_picked.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_picked.clear),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                      ),
                      child: Text(l10n.manasColorPickerClear),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: ManasColors.palette.length,
                itemBuilder: (_, i) {
                  final hex = ManasColors.palette[i];
                  final order = _picked.indexOf(hex);
                  final selected = order >= 0;
                  return InkWell(
                    onTap: () => _toggle(hex),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ManasColors.parse(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? Center(
                              child: Text(
                                '${order + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(List<String>.from(_picked)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(l10n.manasColorPickerApply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
