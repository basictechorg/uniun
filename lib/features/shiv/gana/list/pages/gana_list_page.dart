import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';
import 'package:uniun/features/shiv/gana/list/bloc/gana_list_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Full-screen list of the user's Gana agents — reached from the Shiv home
/// "Gana" button. Provides its own [GanaListBloc] (the bloc reactively reloads
/// on any change to the `Gana` collection). Tapping a card opens its detail;
/// the per-card switch toggles the master enable; "New" opens the form.
class GanaListPage extends StatelessWidget {
  const GanaListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<GanaListBloc>()..add(const GanaListLoadEvent()),
      child: const _GanaListView(),
    );
  }
}

class _GanaListView extends StatelessWidget {
  const _GanaListView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.shivGanaForm),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.ganaListNew),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const StadiumBorder(),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<GanaListBloc, GanaListState>(
        builder: (context, state) {
          if (state.status == GanaListStatus.loading ||
              state.status == GanaListStatus.initial) {
            return const Center(child: DropLoadingIndicator());
          }
          if (state.ganas.isEmpty) {
            return const _EmptyState();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.ganaListSubtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              for (final g in state.ganas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GanaCard(gana: g, lastRun: state.lastRuns[g.ganaId]),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Agent card ───────────────────────────────────────────────────────────────

class _GanaCard extends StatelessWidget {
  const _GanaCard({required this.gana, required this.lastRun});
  final GanaEntity gana;
  final GanaRunEntity? lastRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final on = gana.enabled;
    final br = BorderRadius.circular(16);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: br,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushNamed(
            AppRoutes.shivGanaDetail,
            pathParameters: {'ganaId': gana.ganaId},
          ),
          borderRadius: br,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Agent avatar — tinted while enabled.
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: on
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.auto_mode_rounded,
                        size: 22,
                        color: on
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gana.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: on
                                      ? AppColors.success
                                      : AppColors.outlineVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _statusLine(gana, lastRun, l10n),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: (on && lastRun != null)
                                        ? _lastRunColor(lastRun!.status)
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: on,
                      onChanged: (v) => context.read<GanaListBloc>().add(
                            GanaListToggleEnabledEvent(gana.ganaId, v),
                          ),
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.onSurface.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    _MetaLine(
                      icon: _triggerIcon(gana),
                      value: _triggerSummary(gana, l10n),
                    ),
                    _MetaLine(
                      icon: Icons.hub_rounded,
                      value: _scopeLabel(gana, l10n),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.auto_mode_rounded,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.ganaDrawerEmptyTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ganaDrawerEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.shivGanaForm),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.ganaListNew),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formatters (mirror the Shiv drawer's Gana tile derivations) ──────────────

String _statusLine(GanaEntity g, GanaRunEntity? lastRun, AppLocalizations l10n) {
  if (!g.enabled) return l10n.ganaListPaused;
  if (lastRun == null) return l10n.ganaTileLastRunNever;
  return _lastRunLabel(lastRun, l10n);
}

String _lastRunLabel(GanaRunEntity r, AppLocalizations l10n) {
  final when = _relativeWhen(r.startedAt, l10n);
  return switch (r.status) {
    GanaRunStatus.succeeded => l10n.ganaTileLastRunSucceeded(when),
    GanaRunStatus.skipped => l10n.ganaTileLastRunSkipped(when),
    GanaRunStatus.failed => l10n.ganaTileLastRunFailed(when),
    GanaRunStatus.running => l10n.ganaTileLastRunSucceeded(when),
  };
}

Color _lastRunColor(GanaRunStatus s) => switch (s) {
      GanaRunStatus.succeeded => AppColors.primary,
      GanaRunStatus.skipped => AppColors.onSurfaceVariant,
      GanaRunStatus.failed => AppColors.error,
      GanaRunStatus.running => AppColors.primary,
    };

String _triggerSummary(GanaEntity g, AppLocalizations l10n) {
  if (g.triggerMode == GanaTriggerMode.oneShot) {
    return g.inputType == null
        ? l10n.ganaTileTriggerOnceOnEnable
        : l10n.ganaTileTriggerOnceOnInput;
  }
  final reactive = g.triggerReactive;
  final interval = g.triggerIntervalMinutes;
  if (reactive && interval != null) return l10n.ganaTileTriggerBoth(interval);
  if (reactive) return l10n.ganaTileTriggerReactive;
  if (interval != null) return l10n.ganaTileTriggerInterval(interval);
  return '—';
}

IconData _triggerIcon(GanaEntity g) =>
    (g.triggerReactive && g.triggerMode != GanaTriggerMode.oneShot)
        ? Icons.bolt_rounded
        : Icons.schedule_rounded;

String _scopeLabel(GanaEntity g, AppLocalizations l10n) => g.manasIds.isEmpty
    ? l10n.ganaListScopeAll
    : l10n.ganaListScopeCount(g.manasIds.length);

String _relativeWhen(DateTime t, AppLocalizations l10n) {
  final delta = DateTime.now().difference(t);
  if (delta.inSeconds < 60) return l10n.ganaRelativeJustNow;
  if (delta.inMinutes < 60) return l10n.ganaRelativeMinutes(delta.inMinutes);
  if (delta.inHours < 24) return l10n.ganaRelativeHours(delta.inHours);
  if (delta.inDays < 7) return l10n.ganaRelativeDays(delta.inDays);
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}
