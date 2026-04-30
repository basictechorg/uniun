import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/channels/join/bloc/join_channel_bloc.dart';
import 'package:uniun/channels/join/pages/join_channel_qr_scan_page.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

class JoinChannelPage extends StatelessWidget {
  const JoinChannelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<JoinChannelBloc>()..add(const LoadJoinRelaysEvent()),
      child: const _JoinChannelView(),
    );
  }
}

class _JoinChannelView extends StatefulWidget {
  const _JoinChannelView();

  @override
  State<_JoinChannelView> createState() => _JoinChannelViewState();
}

class _JoinChannelViewState extends State<_JoinChannelView> {
  final _channelIdController = TextEditingController();
  final _relayUrlController = TextEditingController();
  final List<String> _selectedRelays = [];

  @override
  void dispose() {
    _channelIdController.dispose();
    _relayUrlController.dispose();
    super.dispose();
  }

  void _submitJoin() {
    context.read<JoinChannelBloc>().add(
      SubmitJoinChannelEvent(
        channelId: _channelIdController.text,
        selectedRelays: _selectedRelays,
        channelName: '',
      ),
    );
  }

  Future<void> _joinByQr() async {
    final rawPayload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const JoinChannelQrScanPage()),
    );
    if (!mounted || rawPayload == null || rawPayload.isEmpty) return;
    context.read<JoinChannelBloc>().add(
      SubmitJoinChannelQrEvent(rawPayload: rawPayload),
    );
  }

  Future<String?> _showAddRelayDialog() async {
    final l10n = AppLocalizations.of(context)!;
    _relayUrlController.clear();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          title: Text(l10n.joinChannelAddRelay),
          content: TextField(
            controller: _relayUrlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: l10n.joinChannelRelayHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            TextButton(
              onPressed: () async {
                final relayUrl = _relayUrlController.text.trim();
                if (relayUrl.isEmpty) return;
                final bloc = context.read<JoinChannelBloc>();
                final previousLength = bloc.state.availableRelays.length;
                bloc.add(AddJoinRelayEvent(url: relayUrl));
                final nextState = await bloc.stream.firstWhere(
                  (state) =>
                      state.availableRelays.length != previousLength ||
                      state.errorMessage != null,
                );
                if (!dialogContext.mounted) return;
                if (nextState.availableRelays.contains(relayUrl)) {
                  Navigator.of(dialogContext).pop(relayUrl);
                }
              },
              child: Text(l10n.joinChannelAddRelayAction),
            ),
          ],
        );
      },
    );
  }

  void _showRelaySelectorDialog(List<String> availableRelays) {
    final l10n = AppLocalizations.of(context)!;
    final joinChannelBloc = context.read<JoinChannelBloc>();
    showDialog(
      context: context,
      builder: (ctx) {
        return BlocProvider.value(
          value: joinChannelBloc,
          child: StatefulBuilder(
            builder: (dialogContext, setStateDialog) {
              return AlertDialog(
                backgroundColor: AppColors.surfaceContainerLowest,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.joinChannelSelectRelays,
                        style: const TextStyle(color: AppColors.onSurface),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final addedRelay = await _showAddRelayDialog();
                        if (!dialogContext.mounted || addedRelay == null) return;
                        setStateDialog(() {
                          if (!_selectedRelays.contains(addedRelay)) {
                            _selectedRelays.add(addedRelay);
                          }
                        });
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.primary,
                      ),
                      tooltip: l10n.joinChannelAddRelay,
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: BlocBuilder<JoinChannelBloc, JoinChannelState>(
                    builder: (context, state) {
                      final relays = state.availableRelays.isEmpty
                          ? availableRelays
                          : state.availableRelays;
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: relays.length,
                        itemBuilder: (context, index) {
                          final relay = relays[index];
                          final isSelected = _selectedRelays.contains(relay);
                          return CheckboxListTile(
                            activeColor: AppColors.primary,
                            title: Text(
                              relay,
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: isSelected,
                            onChanged: (value) {
                              setStateDialog(() {
                                if (value == true) {
                                  _selectedRelays.add(relay);
                                } else {
                                  _selectedRelays.remove(relay);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.actionDone),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<JoinChannelBloc, JoinChannelState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.joinChannelSuccess),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      },
      child: KeyboardDismissOnTap(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.joinChannelTitle,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          body: BlocBuilder<JoinChannelBloc, JoinChannelState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.joinChannelHeading,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _channelIdController,
                      decoration: InputDecoration(
                        labelText: l10n.joinChannelIdLabel,
                        labelStyle: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      l10n.joinChannelRelaysTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.joinChannelRelaysBody,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (state.isLoadingRelays)
                      const Center(child: CircularProgressIndicator())
                    else
                      InkWell(
                        onTap: () => _showRelaySelectorDialog(state.availableRelays),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedRelays.isEmpty
                                      ? l10n.joinChannelSelectRelays
                                      : l10n.joinChannelSelectedRelays(
                                          _selectedRelays.length,
                                        ),
                                  style: TextStyle(
                                    color: _selectedRelays.isEmpty
                                        ? AppColors.onSurfaceVariant
                                        : AppColors.onSurface,
                                    fontWeight: _selectedRelays.isEmpty
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_selectedRelays.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedRelays
                              .map(
                                (relay) => Chip(
                                  label: Text(
                                    relay,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedRelays.remove(relay);
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: state.isSubmitting ? null : _joinByQr,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(l10n.joinChannelByQr),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submitJoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.joinChannelAction,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
