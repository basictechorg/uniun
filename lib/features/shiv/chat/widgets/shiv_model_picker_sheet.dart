import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/features/shiv/model_select/utils/ai_model_l10n.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Bottom sheet listing BOTH surfaces the user can run Shiv on: the UNIUN
/// cloud models (when connected) and the downloaded on-device models.
/// Picking a row IS the backend switch — a cloud row activates the cloud
/// backend with that model, a local row activates the on-device backend.
/// The [showCloud]/[nullableOptionLabel]/[currentOverrideId]/[onLocalSelected]
/// params let a caller swap that default global-switch behavior for a
/// local, per-caller selection instead (see Gana's usage).
///
/// Show with [showModelPickerSheet] — handles the standard rounded sheet
/// chrome so callers don't repeat the boilerplate.
class ShivModelPickerSheet extends StatefulWidget {
  const ShivModelPickerSheet({
    super.key,
    this.showCloud = true,
    this.nullableOptionLabel,
    this.onNullSelected,
    this.currentOverrideId,
    this.onLocalSelected,
    this.onCloudSelected,
  });

  /// Whether to fetch/show the UNIUN Cloud section at all.
  final bool showCloud;

  /// If set, shows a leading row with this label meaning "no override —
  /// use whatever's globally active". Used by Gana's "use active model"
  /// option; Shiv/Nataraj leave this null (there's no "unset" concept for
  /// the global model).
  final String? nullableOptionLabel;

  /// Called when [nullableOptionLabel]'s row is tapped. Only meaningful
  /// when [nullableOptionLabel] is set.
  final VoidCallback? onNullSelected;

  /// When set, this local model id (`AIModelId.name`) is highlighted as the
  /// current selection instead of whatever's globally active — for a
  /// per-agent override (Gana's `desiredModelId`) that may differ from the
  /// app's active model.
  final String? currentOverrideId;

  /// When set, picking a local row calls this instead of the default
  /// "switch the app's active backend/model" behavior — for a synchronous,
  /// purely-local state update (e.g. Gana's per-agent override) rather than
  /// the global async switch. The sheet still closes itself after calling it.
  final void Function(AIModelEntity)? onLocalSelected;

  /// Same as [onLocalSelected] but for a cloud row.
  final void Function(LlmModelInfo)? onCloudSelected;

  @override
  State<ShivModelPickerSheet> createState() => _ShivModelPickerSheetState();
}

Future<void> showModelPickerSheet(
  BuildContext context, {
  bool showCloud = true,
  String? nullableOptionLabel,
  VoidCallback? onNullSelected,
  String? currentOverrideId,
  void Function(AIModelEntity)? onLocalSelected,
  void Function(LlmModelInfo)? onCloudSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ShivModelPickerSheet(
      showCloud: showCloud,
      nullableOptionLabel: nullableOptionLabel,
      onNullSelected: onNullSelected,
      currentOverrideId: currentOverrideId,
      onLocalSelected: onLocalSelected,
      onCloudSelected: onCloudSelected,
    ),
  );
}

class _ShivModelPickerSheetState extends State<ShivModelPickerSheet> {
  bool _loading = true;
  bool _switching = false;
  List<LlmModelInfo> _cloudModels = const [];
  List<AIModelEntity> _localModels = const [];
  LlmBackendType _activeBackend = LlmBackendType.localGemma;
  String? _activeCloudModelId;
  AIModelId? _activeLocalModelId;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final backendResult = await getIt<GetActiveLlmBackendUseCase>().call();
    final backend = backendResult.fold(
      (_) => LlmBackendType.localGemma,
      (b) => b,
    );

    // Cloud list only when already connected — merely opening the picker
    // must not trigger the silent gateway login. Skipped entirely when the
    // caller's context can't act on a cloud pick anyway (e.g. Gana).
    var cloud = const <LlmModelInfo>[];
    if (widget.showCloud && await getIt<IsUniunCloudConnectedUseCase>().call()) {
      final cloudResult = await getIt<ListCloudLlmModelsUseCase>().call();
      cloud = cloudResult.fold((_) => const [], (list) => list);
    }

    final catalog = await getIt<GetAvailableAIModelsUseCase>().call();
    final downloadedIds = await getIt<GetDownloadedModelIdsUseCase>().call();
    final local =
        catalog.where((m) => downloadedIds.contains(m.modelId)).toList();

    final activeLocalResult = await getIt<GetActiveAIModelUseCase>().call();
    final activeLocalId =
        activeLocalResult.fold((_) => null, (m) => m?.modelId);
    final activeModelResult = await getIt<GetActiveLlmModelUseCase>().call();
    final activeCloudId = activeModelResult.fold(
      (_) => null,
      (m) => m?.backend == LlmBackendType.uniunCloud ? m?.id : null,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _activeBackend = backend;
      _cloudModels = cloud;
      _localModels = local;
      _activeCloudModelId = activeCloudId;
      _activeLocalModelId = activeLocalId;
    });
  }

  Future<void> _selectCloud(LlmModelInfo m) async {
    if (_switching) return;

    final onCloudSelected = widget.onCloudSelected;
    if (onCloudSelected != null) {
      onCloudSelected(m);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _switching = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final switched = await getIt<SetActiveLlmBackendUseCase>()
        .call(LlmBackendType.uniunCloud);
    final failure = await switched.fold(
      (f) async => f,
      (_) async {
        final set = await getIt<SetActiveLlmModelUseCase>().call(m.id);
        return set.fold((f) => f, (_) => null);
      },
    );
    if (!mounted) return;
    if (failure != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(failure.toMessage())),
      );
      setState(() => _switching = false);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _selectLocal(AIModelEntity m) async {
    if (_switching) return;

    // A per-agent override (Gana) is a synchronous local state update, not a
    // global backend switch — no failure path, no spinner needed.
    final onLocalSelected = widget.onLocalSelected;
    if (onLocalSelected != null) {
      onLocalSelected(m);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _switching = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final switched = await getIt<SetActiveLlmBackendUseCase>()
        .call(LlmBackendType.localGemma);
    final failure = await switched.fold(
      (f) async => f,
      (_) async {
        final set =
            await getIt<SetActiveLlmModelUseCase>().call(m.modelId.name);
        return set.fold((f) => f, (_) => null);
      },
    );
    if (!mounted) return;
    if (failure != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(failure.toMessage())),
      );
      setState(() => _switching = false);
      return;
    }
    Navigator.of(context).pop();
  }

  List<LlmModelInfo> get _filteredCloud {
    if (_filter.isEmpty) return _cloudModels;
    final q = _filter.toLowerCase();
    return _cloudModels
        .where((m) =>
            m.displayName.toLowerCase().contains(q) ||
            m.id.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text(
                  l10n.modelPickerTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_switching)
                  DropLoadingIndicator(
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
          // Search bar — only useful when the cloud catalogue is large
          if (_cloudModels.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _filter = v.trim()),
                decoration: InputDecoration(
                  hintText: l10n.modelPickerSearchHint,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          // Body
          Flexible(child: _buildBody(l10n)),
          // Footer CTA — manage (download / delete) on-device models
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed(AppRoutes.aiModelSelection);
                },
                icon: const Icon(Icons.tune_rounded),
                label: Text(l10n.modelPickerManageLocalCta),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DropLoadingIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final cloud = _filteredCloud;
    final nullableLabel = widget.nullableOptionLabel;
    if (cloud.isEmpty && _localModels.isEmpty && nullableLabel == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.modelPickerNoModels,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final overrideId = widget.currentOverrideId;

    return ListView(
      shrinkWrap: true,
      children: [
        if (nullableLabel != null)
          _ModelRow(
            label: nullableLabel,
            isActive: overrideId == null,
            onTap: () {
              widget.onNullSelected?.call();
              Navigator.of(context).pop();
            },
          ),
        if (cloud.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.cloud_outlined,
            label: l10n.modelPickerCloudSection,
          ),
          for (final m in cloud)
            _ModelRow(
              label: m.displayName,
              isActive: overrideId != null
                  ? m.id == overrideId
                  : _activeBackend == LlmBackendType.uniunCloud &&
                      m.id == _activeCloudModelId,
              onTap: () => _selectCloud(m),
            ),
        ],
        if (_localModels.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.phone_iphone_rounded,
            label: l10n.modelPickerLocalSection,
          ),
          for (final m in _localModels)
            _ModelRow(
              label: m.modelId.displayName(l10n),
              isActive: overrideId != null
                  ? m.modelId.name == overrideId
                  : _activeBackend == LlmBackendType.localGemma &&
                      m.modelId == _activeLocalModelId,
              onTap: () => _selectLocal(m),
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Icon(icon,
              size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
