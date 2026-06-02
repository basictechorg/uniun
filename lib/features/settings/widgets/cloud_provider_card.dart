import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Settings card for cloud LLM credentials (OpenRouter, today).
///
/// Empty state: shows a CTA that opens a paste-key dialog.
/// Connected state: shows the active model, a backend toggle (cloud vs
/// on-device), and a Disconnect action.
///
/// Self-contained — uses use cases directly rather than a cubit, since the
/// card has only a handful of states and lives in the slow-changing Settings
/// page. If multiple surfaces grow to share this state, lift to a cubit.
class CloudProviderCard extends StatefulWidget {
  const CloudProviderCard({super.key});

  @override
  State<CloudProviderCard> createState() => _CloudProviderCardState();
}

class _CloudProviderCardState extends State<CloudProviderCard> {
  bool _loading = true;
  bool _hasKey = false;
  String? _activeModelId;
  LlmBackendType _activeBackend = LlmBackendType.localGemma;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasKey = await getIt<HasOpenRouterKeyUseCase>().call();
    final backendResult = await getIt<GetActiveLlmBackendUseCase>().call();
    final activeBackend = backendResult.fold(
      (_) => LlmBackendType.localGemma,
      (b) => b,
    );
    final modelResult = await getIt<GetActiveLlmModelUseCase>().call();
    final activeModel = modelResult.fold(
      (_) => null,
      (m) => m?.backend == LlmBackendType.openRouter ? m?.id : null,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasKey = hasKey;
      _activeBackend = activeBackend;
      _activeModelId = activeModel;
    });
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteKeyDialog(),
    );
    if (entered == null || entered.trim().isEmpty) return;

    final saved = await getIt<SaveOpenRouterKeyUseCase>().call(entered.trim());
    final ok = saved.isRight();
    if (!ok) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.cloudProviderInvalidKey)),
        );
      }
      return;
    }
    // Validate the key by listing models — surfaces fake/invalid keys early.
    final listResult = await getIt<ListAvailableLlmModelsUseCase>().call();
    final validated = await listResult.fold(
      (_) async {
        await getIt<ClearOpenRouterKeyUseCase>().call();
        return false;
      },
      (_) async => true,
    );
    if (!mounted) return;
    if (!validated) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.cloudProviderInvalidKey)),
      );
      return;
    }
    await _load();
  }

  Future<void> _disconnect() async {
    await getIt<ClearOpenRouterKeyUseCase>().call();
    // If cloud was active, fall back to local so the next chat send doesn't
    // hit an empty-credentials state.
    if (_activeBackend == LlmBackendType.openRouter) {
      await getIt<SetActiveLlmBackendUseCase>().call(LlmBackendType.localGemma);
    }
    await _load();
  }

  Future<void> _toggleBackend(bool useCloud) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final target =
        useCloud ? LlmBackendType.openRouter : LlmBackendType.localGemma;
    final result = await getIt<SetActiveLlmBackendUseCase>().call(target);
    result.fold(
      (f) => scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(f.toMessage())),
      ),
      (_) {
        if (target == LlmBackendType.openRouter && _activeModelId == null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.cloudProviderNoActiveModel)),
          );
        }
      },
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return Container(
        height: 84,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — tappable when connected, opens manage flow
          GestureDetector(
            onTap: _hasKey ? null : _connect,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cloudProviderTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hasKey
                            ? l10n.cloudProviderConnectedSubtitle
                            : l10n.cloudProviderEmptySubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _hasKey
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_hasKey)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
          if (_hasKey) ...[
            const SizedBox(height: 16),
            // Active model line
            Row(
              children: [
                const Icon(Icons.cloud_outlined,
                    size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _activeModelId ?? l10n.cloudProviderNoActiveModel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Backend toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    _activeBackend == LlmBackendType.openRouter
                        ? l10n.cloudProviderUseCloud
                        : l10n.cloudProviderUseLocal,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _activeBackend == LlmBackendType.openRouter,
                  onChanged: _toggleBackend,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Disconnect action
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _disconnect,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(l10n.cloudProviderDisconnect),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasteKeyDialog extends StatefulWidget {
  const _PasteKeyDialog();

  @override
  State<_PasteKeyDialog> createState() => _PasteKeyDialogState();
}

class _PasteKeyDialogState extends State<_PasteKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _controller.text = data.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.cloudProviderPasteKeyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.cloudProviderPasteKeyHint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _paste,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.cloudProviderPasteKeyHelper,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
