import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/relay_selector_field.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/router/nav_extensions.dart';
import 'package:uniun/features/channels/join/bloc/join_channel_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

class JoinChannelPage extends StatelessWidget {
  const JoinChannelPage({super.key, this.payload});

  /// Pre-fill data from a QR scan or a `/channel/<id>` deep link that fell
  /// back here because the channel isn't joined yet.
  final UniunQrPayload? payload;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<JoinChannelBloc>(),
      child: _JoinChannelView(payload: payload),
    );
  }
}

class _JoinChannelView extends StatefulWidget {
  const _JoinChannelView({this.payload});

  final UniunQrPayload? payload;

  @override
  State<_JoinChannelView> createState() => _JoinChannelViewState();
}

class _JoinChannelViewState extends State<_JoinChannelView> {
  final _channelIdController = TextEditingController();
  final List<String> _selectedRelays = [];
  String _prefilledName = '';

  @override
  void initState() {
    super.initState();
    final args = widget.payload;
    if (args != null && args.kind == UniunQrKind.publicChannel) {
      _channelIdController.text = args.id;
      _prefilledName = args.name ?? '';
      _selectedRelays
        ..clear()
        ..addAll(args.relays);
    }
  }

  @override
  void dispose() {
    _channelIdController.dispose();
    super.dispose();
  }

  void _submitJoin() {
    context.read<JoinChannelBloc>().add(
      SubmitJoinChannelEvent(
        channelId: _channelIdController.text,
        selectedRelays: _selectedRelays,
        channelName: _prefilledName,
      ),
    );
  }

  Future<void> _joinByQr() async {
    // The unified scanner replaces this page with the right destination, so
    // we just push and let it take over.
    context.pushNamed(AppRoutes.scanQr);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<JoinChannelBloc, JoinChannelState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorText(state.error!, l10n)),
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
          // In-app join → pop back where we came from. A deep-link join lands
          // here as the navigator root, so there's nothing to pop to — open the
          // channel we just joined instead.
          context.popOr(() => context.goNamed(
                AppRoutes.channelDetail,
                pathParameters: {'channelId': _channelIdController.text.trim()},
              ));
        }
      },
      child: KeyboardDismissOnTap(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            centerTitle: true,
            shape: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            leading: UniunBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.joinChannelTitle,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
          body: BlocBuilder<JoinChannelBloc, JoinChannelState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scan a channel QR — the primary affordance.
                    _ScanQrCard(
                      title: l10n.joinChannelScanCardTitle,
                      subtitle: l10n.joinChannelScanCardSubtitle,
                      onTap: state.isSubmitting ? null : _joinByQr,
                    ),
                    const SizedBox(height: 20),
                    _OrDivider(label: l10n.joinChannelOr),
                    const SizedBox(height: 20),
                    // Paste channel id (hex — mono).
                    TextField(
                      controller: _channelIdController,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.joinChannelIdHint,
                        hintStyle: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.outline,
                        ),
                        prefixIcon: const Icon(
                          Icons.tag_rounded,
                          size: 20,
                          color: AppColors.outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RelaySelectorField(
                      selected: _selectedRelays,
                      onChanged: (next) => setState(() => _selectedRelays
                        ..clear()
                        ..addAll(next)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.joinChannelRelaysBody,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submitJoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: DropLoadingIndicator(
                                  size: 20,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                l10n.joinChannelAction,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
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

/// Maps a [JoinChannelError] from the bloc to a localized message.
String _errorText(JoinChannelError error, AppLocalizations l10n) {
  return switch (error) {
    JoinChannelError.invalidId => l10n.joinChannelErrorInvalidId,
    JoinChannelError.noRelay => l10n.joinChannelErrorNoRelay,
    JoinChannelError.relaySaveFailed => l10n.joinChannelErrorRelaySaveFailed,
    JoinChannelError.saveFailed => l10n.joinChannelErrorSaveFailed,
  };
}

// Prominent tap-to-scan card at the top of the join flow. A null [onTap]
// renders it disabled (while a join is submitting).
class _ScanQrCard extends StatelessWidget {
  const _ScanQrCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hairline "or" divider between the scan card and the paste-id input.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: AppColors.outlineVariant.withValues(alpha: 0.4),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.outline),
          ),
        ),
        line,
      ],
    );
  }
}
