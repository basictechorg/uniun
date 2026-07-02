import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Bottom sheet that lists every model available on the **active backend**
/// (local Gemma models when local is active, OpenRouter catalogue when cloud
/// is active). Lets the user switch the selected model with one tap.
///
/// Show with [showModelPickerSheet] — handles the standard rounded sheet
/// chrome so callers don't repeat the boilerplate.
class ShivModelPickerSheet extends StatefulWidget {
  const ShivModelPickerSheet({super.key});

  @override
  State<ShivModelPickerSheet> createState() => _ShivModelPickerSheetState();
}

Future<void> showModelPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const ShivModelPickerSheet(),
  );
}

class _ShivModelPickerSheetState extends State<ShivModelPickerSheet> {
  bool _loading = true;
  LlmBackendType _backend = LlmBackendType.localGemma;
  List<LlmModelInfo> _models = const [];
  String? _activeModelId;
  String _filter = '';
  String? _errorMessage;

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
    final modelsResult = await getIt<ListAvailableLlmModelsUseCase>().call();
    final activeResult = await getIt<GetActiveLlmModelUseCase>().call();

    if (!mounted) return;

    modelsResult.fold(
      (f) => setState(() {
        _backend = backend;
        _models = const [];
        _activeModelId = activeResult.fold((_) => null, (m) => m?.id);
        _loading = false;
        _errorMessage = f.toMessage();
      }),
      (list) => setState(() {
        _backend = backend;
        _models = list;
        _activeModelId = activeResult.fold((_) => null, (m) => m?.id);
        _loading = false;
        _errorMessage = null;
      }),
    );
  }

  Future<void> _select(LlmModelInfo m) async {
    final result = await getIt<SetActiveLlmModelUseCase>().call(m.id);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.toMessage())),
      ),
      (_) {
        setState(() => _activeModelId = m.id);
        Navigator.of(context).pop();
      },
    );
  }

  List<LlmModelInfo> get _filtered {
    if (_filter.isEmpty) return _models;
    final q = _filter.toLowerCase();
    return _models
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
                _BackendChip(
                  backend: _backend,
                  l10n: l10n,
                ),
              ],
            ),
          ),
          // Search bar — only useful when the catalogue is large (cloud)
          if (_backend == LlmBackendType.openRouter)
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
          Expanded(child: _buildBody(l10n)),
          // Footer CTA
          _FooterCta(backend: _backend, l10n: l10n, onTapManageLocal: () {
            Navigator.of(context).pop();
            context.pushNamed(AppRoutes.aiModelSelection);
          }),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropLoadingIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            if (_backend == LlmBackendType.openRouter) ...[
              const SizedBox(height: 12),
              Text(
                l10n.modelPickerLoadingCloud,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          l10n.modelPickerNoModels,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final m = filtered[i];
        final isActive = m.id == _activeModelId;
        return InkWell(
          onTap: () => _select(m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (m.id != m.displayName) ...[
                        const SizedBox(height: 2),
                        Text(
                          m.id,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
      },
    );
  }
}

class _BackendChip extends StatelessWidget {
  const _BackendChip({required this.backend, required this.l10n});
  final LlmBackendType backend;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isCloud = backend == LlmBackendType.openRouter;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCloud ? Icons.cloud_outlined : Icons.phone_iphone_rounded,
            size: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            isCloud ? l10n.modelPickerCloudSection : l10n.modelPickerLocalSection,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterCta extends StatelessWidget {
  const _FooterCta({
    required this.backend,
    required this.l10n,
    required this.onTapManageLocal,
  });
  final LlmBackendType backend;
  final AppLocalizations l10n;
  final VoidCallback onTapManageLocal;

  @override
  Widget build(BuildContext context) {
    // Only show manage-local footer for now; cloud connect lives in Settings.
    if (backend != LlmBackendType.localGemma) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: onTapManageLocal,
          icon: const Icon(Icons.tune_rounded),
          label: Text(l10n.modelPickerManageLocalCta),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
