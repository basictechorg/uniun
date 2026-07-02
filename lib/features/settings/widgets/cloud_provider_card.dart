import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Settings row for cloud LLM credentials (OpenRouter, today). Lives inside the
/// AI · Shiv group alongside the on-device model row, so it renders as a single
/// [SettingsRow] (not its own card).
///
/// Empty state: the whole row opens a paste-key bottom sheet.
/// Connected state: the whole row opens a manage bottom sheet (active model,
/// backend toggle cloud vs on-device, and Disconnect).
///
/// Self-contained — uses use cases directly rather than a cubit, since the
/// row has only a handful of states and lives in the slow-changing Settings
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
    final entered = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PasteKeySheet(),
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

  /// Connected-state controls (active model · backend toggle · disconnect),
  /// lifted into a bottom sheet so the row itself stays a single tappable row
  /// inside the AI settings group.
  Future<void> _openManageSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.cloudProviderTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Active model line
                    Row(
                      children: [
                        Icon(Icons.cloud_outlined,
                            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _activeModelId ?? l10n.cloudProviderNoActiveModel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Backend toggle
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _activeBackend == LlmBackendType.openRouter
                                ? l10n.cloudProviderUseCloud
                                : l10n.cloudProviderUseLocal,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _activeBackend == LlmBackendType.openRouter,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (useCloud) async {
                            await _toggleBackend(useCloud);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
                    const SizedBox(height: 4),
                    // Disconnect action
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await _disconnect();
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        },
                        icon: const Icon(Icons.link_off_rounded, size: 18),
                        label: Text(l10n.cloudProviderDisconnect),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return SettingsRow(
        icon: Icons.cloud_outlined,
        label: l10n.cloudProviderTitle,
        showChevron: false,
        trailing: SizedBox(
          width: 18,
          height: 18,
          child: DropLoadingIndicator(size: 18, color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (!_hasKey) {
      // Empty state — whole row opens the paste-key sheet.
      return SettingsRow(
        icon: Icons.cloud_outlined,
        label: l10n.cloudProviderTitle,
        subtitle: l10n.cloudProviderEmptySubtitle,
        onTap: _connect,
      );
    }

    // Connected — whole row opens the manage sheet.
    return SettingsRow(
      icon: Icons.cloud_done_outlined,
      label: l10n.cloudProviderTitle,
      subtitle: l10n.cloudProviderConnectedSubtitle,
      onTap: _openManageSheet,
    );
  }
}

/// Paste-key input as a bottom sheet (the app prefers bottom sheets over modal
/// dialogs — see CLAUDE.md). Returns the entered key via `Navigator.pop`.
class _PasteKeySheet extends StatefulWidget {
  const _PasteKeySheet();

  @override
  State<_PasteKeySheet> createState() => _PasteKeySheetState();
}

class _PasteKeySheetState extends State<_PasteKeySheet> {
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
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.cloudProviderPasteKeyTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
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
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary),
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                    child: Text(l10n.actionSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
