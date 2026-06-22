import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';
import 'package:uniun/domain/usecases/gana_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Lightweight read-only detail page — name + summary + recent runs.
/// The Edit button hands off to [GanaFormPage] for actual changes; this
/// page deliberately does not own form state.
class GanaDetailPage extends StatefulWidget {
  const GanaDetailPage({super.key, required this.ganaId});
  final String ganaId;

  @override
  State<GanaDetailPage> createState() => _GanaDetailPageState();
}

class _GanaDetailPageState extends State<GanaDetailPage> {
  GanaEntity? _gana;
  List<GanaRunEntity> _runs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ganaRes = await getIt<GetGanaByIdUseCase>().call(widget.ganaId);
    final runsRes = await getIt<GetGanaRunsUseCase>().call(widget.ganaId);
    if (!mounted) return;
    setState(() {
      _gana = ganaRes.fold<GanaEntity?>((_) => null, (g) => g);
      _runs = runsRes.fold<List<GanaRunEntity>>((_) => const [], (l) => l);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final g = _gana;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        scrolledUnderElevation: 0,
        leading: UniunBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          g?.name ?? l10n.ganaFormEditTitleFallback,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.primary,
            onPressed: g == null
                ? null
                : () async {
                    final changed = await context.pushNamed<bool>(
                      AppRoutes.shivGanaForm,
                      extra: {'ganaId': g.ganaId},
                    );
                    if (changed == true && mounted) _load();
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: DropLoadingIndicator(
                  color: AppColors.primary))
          : g == null
              ? Center(
                  child: Text(
                  l10n.ganaFormEditTitleFallback,
                  style:
                      const TextStyle(color: AppColors.onSurfaceVariant),
                ))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (g.description != null && g.description!.isNotEmpty) ...[
                      Text(
                        g.description!,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _StatusRow(gana: g),
                    const SizedBox(height: 24),
                    Text(
                      l10n.ganaFormRunsSectionTitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_runs.isEmpty)
                      Text(
                        l10n.ganaFormRunsEmpty,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant),
                      )
                    else
                      for (final r in _runs) _RunTile(run: r),
                  ],
                ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.gana});
  final GanaEntity gana;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Enabled', gana.enabled ? 'Yes' : 'No'),
          _kv('Manases', gana.manasIds.length.toString()),
          _kv('Input',
              gana.inputType?.name ?? 'standalone (interval-only)'),
          _kv('Output', gana.outputType.name),
          _kv('Mode',
              gana.triggerMode == GanaTriggerMode.oneShot ? 'one-shot' : 'recurring'),
          // Interval is meaningless in one-shot — the engine ignores it.
          // Hide it so the UI matches the engine's actual behavior.
          if (gana.triggerMode == GanaTriggerMode.recurring &&
              gana.triggerIntervalMinutes != null)
            _kv('Interval', '${gana.triggerIntervalMinutes}m'),
          if (gana.triggerReactive) _kv('Reactive', 'on'),
          if (gana.triggerMode == GanaTriggerMode.recurring &&
              gana.maxOutputs != null)
            _kv('Max notes', gana.maxOutputs!.toString()),
          if (gana.lastRunAt != null)
            _kv('Last run', gana.lastRunAt!.toLocal().toString()),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                k,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.onSurface),
              ),
            ),
          ],
        ),
      );
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});
  final GanaRunEntity run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (run.status) {
      GanaRunStatus.succeeded => (l10n.ganaRunStatusSucceeded, AppColors.primary),
      GanaRunStatus.skipped => (l10n.ganaRunStatusSkipped, AppColors.onSurfaceVariant),
      GanaRunStatus.failed => (l10n.ganaRunStatusFailed, AppColors.error),
      GanaRunStatus.running => (l10n.ganaRunStatusRunning, AppColors.primary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${run.startedAt.toLocal()}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
                if (run.skipReason != null)
                  Text(
                    run.skipReason!.name,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                if (run.error != null)
                  Text(
                    run.error!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.error),
                  ),
                if (run.outputEventId != null)
                  Text(
                    'output: ${run.outputEventId}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
