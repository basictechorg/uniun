import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/relay/relay_entity.dart';
import 'package:uniun/domain/usecases/delete_relay_usecase.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/settings/cubit/settings_cubit.dart';
import 'package:uniun/features/settings/widgets/section_label.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';

class IdentityCard extends StatelessWidget {
  const IdentityCard({super.key, required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsGroup(
      children: [
        SettingsRow(
          icon: Icons.key_rounded,
          label: l10n.identityKeys,
          onTap: () => _showKeysSheet(context),
        ),
        SettingsRow(
          icon: Icons.cell_tower_rounded,
          label: l10n.identityRelays,
          onTap: () => _showRelaysSheet(context),
        ),
        SettingsRow(
          icon: Icons.block_rounded,
          label: l10n.settingsBlockedUsers,
          onTap: () => context.pushNamed(AppRoutes.blockedUsers),
        ),
      ],
    );
  }

  void _showKeysSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _KeysSheet(npub: state.npub ?? ''),
    );
  }

  void _showRelaysSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _RelaysSheet(),
    );
  }
}

// ── Grabber ──────────────────────────────────────────────────────────────────

/// The 36×4 pill handle pinned to the top of every settings bottom sheet
/// (DESIGN.md §2.2 bottom-sheet pattern).
class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

// ── Combined Keys Sheet ────────────────────────────────────────────────────────

class _KeysSheet extends StatefulWidget {
  const _KeysSheet({required this.npub});
  final String npub;

  @override
  State<_KeysSheet> createState() => _KeysSheetState();
}

class _KeysSheetState extends State<_KeysSheet> {
  bool _nsecVisible = false;
  String? _nsec;
  bool _nsecLoading = false;

  Future<void> _revealNsec() async {
    if (_nsecVisible) {
      setState(() => _nsecVisible = false);
      return;
    }
    setState(() => _nsecLoading = true);
    try {
      final result = await getIt<GetActiveUserUseCase>().call();
      final nsec = result.fold((_) => null, (u) => u.nsec);
      if (mounted) {
        setState(() {
          _nsec = nsec;
          _nsecVisible = true;
          _nsecLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nsecLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetGrabber(),
          const SizedBox(height: 18),
          Text(
            l10n.identityYourKeys,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.identityNeverShare,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),

          // ── Public Key ─────────────────────────────────────────────────
          const SizedBox(height: 24),
          SettingsSectionLabel(l10n.identityPublicKey,
              icon: Icons.lock_open_rounded),
          const SizedBox(height: 8),
          _KeyBox(
            text: widget.npub,
            onCopy: () =>
                _copy(context, widget.npub, l10n.identityPublicKeyCopied),
          ),

          // ── Private Key ────────────────────────────────────────────────
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.identityPrivateKey,
              icon: Icons.lock_rounded),
          const SizedBox(height: 8),

          if (!_nsecVisible)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _nsecLoading ? null : _revealNsec,
                icon: _nsecLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: DropLoadingIndicator(
                          size: 16,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.visibility_rounded, size: 18),
                label: Text(l10n.identityRevealPrivateKey),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.identityNeverShareKey,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _KeyBox(
              text: _nsec ?? '',
              onCopy: () =>
                  _copy(context, _nsec ?? '', l10n.identityPrivateKeyCopied),
              onHide: _revealNsec,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Inset mono field showing a key (npub / nsec) with a tinted "Copy" pill and,
/// for the revealed secret key, a hide toggle. Mirrors the onboarding
/// `KeyCard` field so the settings key view reads as the same component.
class _KeyBox extends StatelessWidget {
  const _KeyBox({required this.text, required this.onCopy, this.onHide});
  final String text;
  final VoidCallback onCopy;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontFamily: 'monospace',
                color: AppColors.onSurface,
              ),
            ),
          ),
          if (onHide != null) ...[
            const SizedBox(width: 4),
            InkResponse(
              onTap: onHide,
              radius: 22,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.visibility_off_rounded,
                    size: 18, color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(width: 2),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_copy_rounded,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      l10n.actionCopy,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Relays Sheet ───────────────────────────────────────────────────────────────

class _RelaysSheet extends StatefulWidget {
  const _RelaysSheet();

  @override
  State<_RelaysSheet> createState() => _RelaysSheetState();
}

class _RelaysSheetState extends State<_RelaysSheet> {
  bool _loading = true;
  List<RelayEntity> _relays = [];

  final TextEditingController _addController = TextEditingController();
  bool _adding = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRelays();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadRelays() async {
    final result = await getIt<GetRelaysUseCase>().call();
    if (!mounted) return;
    setState(() {
      _relays = result.fold((_) => <RelayEntity>[], (list) => list);
      _loading = false;
    });
  }

  void _toggleAdd() {
    setState(() {
      _adding = !_adding;
      if (!_adding) _addController.clear();
    });
  }

  Future<void> _submitAdd() async {
    final url = _addController.text.trim();
    if (url.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final result = await getIt<SaveRelayUseCase>().call(url);
    if (!mounted) return;
    result.fold(
      (f) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.relayAddDialogError(f.toString()))),
        );
      },
      (_) {
        _addController.clear();
        setState(() {
          _saving = false;
          _adding = false;
        });
        _loadRelays();
      },
    );
  }

  Future<void> _confirmDelete(RelayEntity relay) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(l10n.relayRemoveDialogTitle),
        content: Text(l10n.relayRemoveDialogBody(relay.url)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.relayRemoveDialogAction,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await getIt<DeleteRelayUseCase>().call(relay.url);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.toString())),
      ),
      (_) => _loadRelays(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetGrabber(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.identityRelaysSheetTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleAdd,
                icon: Icon(
                    _adding
                        ? Icons.close_rounded
                        : Icons.add_circle_outline_rounded,
                    color: AppColors.primary),
                tooltip: l10n.relaySelectorAddTooltip,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.identityRelaysSubtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          if (_adding) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    autofocus: true,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitAdd(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: AppColors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.relayAddDialogHint,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _saving ? null : _submitAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: DropLoadingIndicator(
                                size: 18, color: AppColors.onPrimary),
                          )
                        : Text(l10n.relayAddDialogAction),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: DropLoadingIndicator(
                      size: 24, color: AppColors.primary),
                ),
              ),
            )
          else if (_relays.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.relayManageEmpty,
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            Container(
              decoration: kSettingsCardDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kSettingsCardRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _relays.length; i++) ...[
                      if (i > 0) const SettingsRowDivider(),
                      _RelayRow(
                        relay: _relays[i],
                        onRemove: () => _confirmDelete(_relays[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One relay inside the grouped relays card: a connected dot, the mono url, and
/// either a system-relay shield or a remove control.
class _RelayRow extends StatelessWidget {
  const _RelayRow({required this.relay, required this.onRemove});

  final RelayEntity relay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          const SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              relay.url,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppColors.onSurface,
              ),
            ),
          ),
          if (relay.isSystem)
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Icon(Icons.shield_outlined,
                  size: 16, color: AppColors.onSurfaceVariant),
            )
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.error),
              tooltip: l10n.relayManageRemoveTooltip,
            ),
        ],
      ),
    );
  }
}

