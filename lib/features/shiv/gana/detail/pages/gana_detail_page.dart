import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/router/app_routes.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        scrolledUnderElevation: 0,
        leading: UniunBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          g?.name ?? l10n.ganaFormEditTitleFallback,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: Theme.of(context).colorScheme.primary,
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
          ? Center(
              child: DropLoadingIndicator(
                  color: Theme.of(context).colorScheme.primary))
          : g == null
              ? Center(
                  child: Text(
                  l10n.ganaFormEditTitleFallback,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _StatusRow(gana: g),
                    const SizedBox(height: 24),
                    Text(
                      l10n.ganaFormRunsSectionTitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_runs.isEmpty)
                      Text(
                        l10n.ganaFormRunsEmpty,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(context, 'Enabled', gana.enabled ? 'Yes' : 'No'),
          _kv(context, l10n.ganaDetailManasesLabel,
              gana.manasIds.length.toString()),
          _kv(context, 'Input',
              gana.inputType?.name ?? 'standalone (interval-only)'),
          _kv(context, 'Output', gana.outputType.name),
          _kv(context, 'Mode',
              gana.triggerMode == GanaTriggerMode.oneShot ? 'one-shot' : 'recurring'),
          // Interval is meaningless in one-shot — the engine ignores it.
          // Hide it so the UI matches the engine's actual behavior.
          if (gana.triggerMode == GanaTriggerMode.recurring &&
              gana.triggerIntervalMinutes != null)
            _kv(context, 'Interval', '${gana.triggerIntervalMinutes}m'),
          if (gana.triggerReactive) _kv(context, 'Reactive', 'on'),
          if (gana.triggerMode == GanaTriggerMode.recurring &&
              gana.maxOutputs != null)
            _kv(context, 'Max notes', gana.maxOutputs!.toString()),
          if (gana.lastRunAt != null)
            _kv(context, 'Last run', gana.lastRunAt!.toLocal().toString()),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                  fontSize: 13, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});
  final GanaRunEntity run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (run.status) {
      GanaRunStatus.succeeded => (l10n.ganaRunStatusSucceeded, Theme.of(context).colorScheme.primary),
      GanaRunStatus.skipped => (l10n.ganaRunStatusSkipped, Theme.of(context).colorScheme.onSurfaceVariant),
      GanaRunStatus.failed => (l10n.ganaRunStatusFailed, Theme.of(context).colorScheme.error),
      GanaRunStatus.running => (l10n.ganaRunStatusRunning, Theme.of(context).colorScheme.primary),
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
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                if (run.error != null)
                  Text(
                    run.error!,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.error),
                  ),
                if (run.outputEventId != null)
                  Text(
                    'output: ${run.outputEventId}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
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
