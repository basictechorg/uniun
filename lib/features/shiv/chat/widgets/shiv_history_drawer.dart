import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_conversation_tile.dart';
import 'package:uniun/features/shiv/gana/list/bloc/gana_list_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Side drawer for Shiv. Hosts two collapsible sections:
///   1. GANAS — list of user-defined AI workers (new).
///   2. CONVERSATIONS — existing chat history (unchanged behaviour).
///
/// Add as `drawer:` on the Shiv page Scaffold. Open programmatically via
/// [ShivHistoryDrawer.open].
class ShivHistoryDrawer extends StatelessWidget {
  const ShivHistoryDrawer({super.key});

  static void open(BuildContext context) =>
      Scaffold.of(context).openDrawer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final top = MediaQuery.of(context).padding.top;

    return Drawer(
      width: 280,
      backgroundColor: AppColors.surfaceContainerLow,
      child: BlocProvider(
        create: (_) =>
            getIt<GanaListBloc>()..add(const GanaListLoadEvent()),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 20,
                right: 8,
                top: top + 16,
                bottom: 12,
              ),
              color: AppColors.surface,
              child: Row(
                children: [
                  Text(
                    l10n.shivConversations,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context
                          .read<ShivAIBloc>()
                          .add(const ShivAIEvent.createConversation());
                    },
                    icon: const Icon(Icons.add_rounded),
                    color: AppColors.primary,
                    tooltip: l10n.shivNewConversationTooltip,
                  ),
                ],
              ),
            ),
            const Expanded(
              child: _DrawerBody(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerBody extends StatelessWidget {
  const _DrawerBody();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: const [
        _GanasSection(),
        SizedBox(height: 12),
        Divider(height: 1, color: AppColors.outlineVariant),
        SizedBox(height: 12),
        _ConversationsSection(),
      ],
    );
  }
}

// ── Ganas section ────────────────────────────────────────────────────────────

class _GanasSection extends StatelessWidget {
  const _GanasSection();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
          child: Row(
            children: [
              Text(
                l10n.ganaDrawerSectionTitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed(AppRoutes.shivGanaForm);
                },
                child: Text(
                  l10n.ganaDrawerNewButton,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        BlocBuilder<GanaListBloc, GanaListState>(
          builder: (context, state) {
            if (state.status == GanaListStatus.loading ||
                state.status == GanaListStatus.initial) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              );
            }
            if (state.ganas.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ganaDrawerEmptyTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.ganaDrawerEmptyBody,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final g in state.ganas)
                  _GanaTile(gana: g, lastRun: state.lastRuns[g.ganaId]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GanaTile extends StatelessWidget {
  const _GanaTile({required this.gana, required this.lastRun});
  final GanaEntity gana;
  final GanaRunEntity? lastRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.pushNamed(
          AppRoutes.shivGanaDetail,
          pathParameters: {'ganaId': gana.ganaId},
        );
      },
      onLongPress: () => _showSheet(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(
                color: gana.enabled
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gana.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _triggerSummary(gana, l10n),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (lastRun != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _lastRunLabel(lastRun!, l10n),
                      style: TextStyle(
                        fontSize: 11,
                        color: _lastRunColor(lastRun!.status),
                      ),
                    ),
                  ] else
                    Text(
                      l10n.ganaTileLastRunNever,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (!gana.enabled)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.ganaTileDisabled,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    final bloc = context.read<GanaListBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                gana.enabled ? Icons.pause_circle_outline : Icons.play_arrow,
                color: AppColors.primary,
              ),
              title: Text(gana.enabled ? 'Disable' : 'Enable'),
              onTap: () {
                bloc.add(GanaListToggleEnabledEvent(
                    gana.ganaId, !gana.enabled));
                Navigator.of(sheetCtx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                context.pushNamed(
                  AppRoutes.shivGanaForm,
                  extra: {'ganaId': gana.ganaId},
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                bloc.add(GanaListDeleteEvent(gana.ganaId));
                Navigator.of(sheetCtx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _triggerSummary(GanaEntity g, AppLocalizations l10n) {
    final reactive = g.triggerReactive;
    final interval = g.triggerIntervalMinutes;
    if (reactive && interval != null) return l10n.ganaTileTriggerBoth(interval);
    if (reactive) return l10n.ganaTileTriggerReactive;
    if (interval != null) return l10n.ganaTileTriggerInterval(interval);
    return '—';
  }

  String _lastRunLabel(GanaRunEntity r, AppLocalizations l10n) {
    final when = _relativeWhen(r.startedAt);
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

  static String _relativeWhen(DateTime t) {
    final delta = DateTime.now().difference(t);
    if (delta.inSeconds < 60) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }
}

// ── Conversations section (existing behaviour, just sectioned) ──────────────

class _ConversationsSection extends StatelessWidget {
  const _ConversationsSection();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShivAIBloc, ShivAIState>(
      builder: (context, state) {
        if (state.conversations.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                l10n.shivNoConversations,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final conv in state.conversations)
              ShivConversationTile(
                conversation: conv,
                isActive: state.activeConversation?.conversationId ==
                    conv.conversationId,
                onTap: () {
                  Navigator.of(context).pop();
                  context
                      .read<ShivAIBloc>()
                      .add(ShivAIEvent.openConversation(
                          conv.conversationId));
                },
                onDelete: () {
                  context
                      .read<ShivAIBloc>()
                      .add(ShivAIEvent.deleteConversation(
                          conv.conversationId));
                },
              ),
          ],
        );
      },
    );
  }
}
