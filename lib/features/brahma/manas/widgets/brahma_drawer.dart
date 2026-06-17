import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/features/brahma/manas/bloc/manas_list_bloc.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Side drawer for Brahma. Header + the "Brahma" full-graph entry +
/// per-Manas tiles + a "+ New Manas" affordance. Tapping a tile scopes
/// the existing [GraphBloc] to that Manas's membership; tapping "Brahma"
/// returns to the full unscoped graph.
class BrahmaDrawer extends StatelessWidget {
  const BrahmaDrawer({super.key, this.activeManasId});

  /// Currently-scoped Manas id (null = full Brahma graph). The matching tile
  /// renders in the active style.
  final String? activeManasId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<ManasListBloc>()..add(const ManasListLoadEvent()),
      child: _BrahmaDrawerView(activeManasId: activeManasId),
    );
  }
}

class _BrahmaDrawerView extends StatelessWidget {
  const _BrahmaDrawerView({required this.activeManasId});
  final String? activeManasId;

  void _close(BuildContext context) => Navigator.pop(context);

  void _scopeToManas(BuildContext context, String? manasId) {
    final graphBloc = context.read<GraphBloc>();
    _close(context);
    graphBloc.add(LoadGraphEvent(manasId: manasId));
  }

  Future<void> _openForm(BuildContext context, {String? manasId}) async {
    final listBloc = context.read<ManasListBloc>();
    _close(context);
    final saved = await context.pushNamed<bool>(
      AppRoutes.brahmaManasForm,
      extra: manasId == null ? null : {'manasId': manasId},
    );
    if (saved == true) {
      listBloc.add(const ManasListLoadEvent());
    }
  }

  void _showTileActions(BuildContext context, ManasEntity manas) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
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
              const SizedBox(height: 8),
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: Text(l10n.manasTileActionEdit),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openForm(context, manasId: manas.manasId);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  l10n.manasTileActionDelete,
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final ok = await _confirmDelete(context, manas.name);
                  if (ok != true) return;
                  if (!context.mounted) return;
                  context
                      .read<ManasListBloc>()
                      .add(ManasListDeleteEvent(manas.manasId));
                  // If the deleted Manas was the active scope, fall back to the
                  // full graph.
                  if (activeManasId == manas.manasId) {
                    context
                        .read<GraphBloc>()
                        .add(const LoadGraphEvent());
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.manasDeleteConfirmTitle),
        content: Text(l10n.manasDeleteConfirmBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.manasDeleteConfirmCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l10n.manasDeleteConfirmConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: AppColors.surface,
      width: 280,
      child: Column(
        children: [
          _Header(
            title: l10n.manasDrawerHeaderTitle,
            subtitle: l10n.manasDrawerHeaderSubtitle,
            onClose: () => _close(context),
          ),
          Expanded(
            child: BlocBuilder<ManasListBloc, ManasListState>(
              builder: (context, state) {
                return ListView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 12),
                  children: [
                    _BrahmaEntryTile(
                      active: activeManasId == null,
                      onTap: () => _scopeToManas(context, null),
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: l10n.manasDrawerSectionTitle,
                      onAdd: () => _openForm(context),
                    ),
                    const SizedBox(height: 6),
                    if (state.status == ManasListStatus.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else if (state.manases.isEmpty)
                      _EmptyState(
                        title: l10n.manasDrawerEmptyStateTitle,
                        body: l10n.manasDrawerEmptyStateBody,
                        ctaLabel: l10n.manasDrawerEmptyStateCta,
                        onCta: () => _openForm(context),
                      )
                    else
                      ...[
                        for (final m in state.manases)
                          _ManasTile(
                            manas: m,
                            active: m.manasId == activeManasId,
                            onTap: () => _scopeToManas(context, m.manasId),
                            onLongPress: () => _showTileActions(context, m),
                          ),
                      ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 8, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.onSurfaceVariant),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.outline,
              ),
            ),
          ),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 2),
                  Text(
                    AppLocalizations.of(context)!.manasDrawerNewManasButton,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrahmaEntryTile extends StatelessWidget {
  const _BrahmaEntryTile({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.manasDrawerBrahmaEntryTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? AppColors.primary
                          : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.manasDrawerBrahmaEntrySubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManasTile extends StatelessWidget {
  const _ManasTile({
    required this.manas,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final ManasEntity manas;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  ManasIcons.byName(manas.iconName),
                  color: active
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manas.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      manas.noteCount == 0
                          ? l10n.manasTileEmptyHint
                          : l10n.manasDrawerTileNoteCount(manas.noteCount),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCta,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}
