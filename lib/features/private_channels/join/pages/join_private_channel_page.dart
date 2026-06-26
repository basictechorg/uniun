import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/relay_selector_field.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/router/nav_extensions.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/private_channels/join/bloc/join_private_channel_bloc.dart';

class JoinPrivateChannelPage extends StatelessWidget {
  const JoinPrivateChannelPage({super.key, this.payload});

  /// Pre-fill data from a QR scan or a `/private/<id>` deep link that fell
  /// back here because the channel isn't joined yet.
  final UniunQrPayload? payload;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<JoinPrivateChannelBloc>(),
      child: _JoinPrivateChannelView(payload: payload),
    );
  }
}

class _JoinPrivateChannelView extends StatefulWidget {
  const _JoinPrivateChannelView({this.payload});

  final UniunQrPayload? payload;

  @override
  State<_JoinPrivateChannelView> createState() => _JoinPrivateChannelViewState();
}

class _JoinPrivateChannelViewState extends State<_JoinPrivateChannelView> {
  final _groupIdController = TextEditingController();
  final List<String> _selectedRelays = [];

  @override
  void initState() {
    super.initState();
    final args = widget.payload;
    if (args != null && args.kind == UniunQrKind.privateChannel) {
      _groupIdController.text = args.id;
      _selectedRelays
        ..clear()
        ..addAll(args.relays);
    }
  }

  @override
  void dispose() {
    _groupIdController.dispose();
    super.dispose();
  }

  void _submit() {
    final groupId = _groupIdController.text.trim();
    if (groupId.isEmpty) return;

    context.read<JoinPrivateChannelBloc>().add(
      SubmitJoinPrivateChannelEvent(groupId: groupId, relays: _selectedRelays),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<JoinPrivateChannelBloc, JoinPrivateChannelState>(
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
              content: Text(l10n.joinPrivateChannelSuccess),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // In-app join → pop back where we came from. A deep-link join lands
          // here as the navigator root, so there's nothing to pop to — open the
          // channel we just joined instead.
          context.popOr(() => context.goNamed(
                AppRoutes.privateChannelDetail,
                pathParameters: {'groupId': _groupIdController.text.trim()},
              ));
        }
      },
      child: KeyboardDismissOnTap(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            shape: const Border(
              bottom: BorderSide(color: AppColors.borderSubtle),
            ),
            leading: UniunBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.joinPrivateChannelTitle,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
          body: BlocBuilder<JoinPrivateChannelBloc, JoinPrivateChannelState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Encrypted eyebrow ──────────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.lock_rounded,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          l10n.joinPrivateChannelEncrypted.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Scan a private channel QR (prominent card) ─────────
                    _ScanQrCard(
                      title: l10n.joinPrivateChannelScanCardTitle,
                      subtitle: l10n.joinPrivateChannelScanCardSubtitle,
                      onTap: state.isSubmitting
                          ? null
                          : () => context.pushNamed(AppRoutes.scanQr),
                    ),

                    // ── or ─────────────────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: _OrDivider(),
                    ),

                    // ── Group ID ───────────────────────────────────────────
                    TextField(
                      controller: _groupIdController,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceLow,
                        hintText: l10n.joinPrivateChannelGroupIdHint,
                        hintStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(Icons.key_rounded,
                            size: 20, color: AppColors.onSurfaceVariant),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Relay (shared multi-relay selector) ────────────────
                    RelaySelectorField(
                      selected: _selectedRelays,
                      onChanged: (next) => setState(() => _selectedRelays
                        ..clear()
                        ..addAll(next)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.joinPrivateChannelGroupIdHelper,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),

                    // ── Approval info ──────────────────────────────────────
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.how_to_reg_rounded,
                              size: 20, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.joinPrivateChannelApprovalInfo,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Request to join ────────────────────────────────────
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.5),
                          disabledForegroundColor: AppColors.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                                l10n.joinPrivateChannelAction,
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

/// Prominent tappable card for opening the QR scanner — a tint circle + icon
/// above a title/subtitle. Same action as the old "Scan QR" button.
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner_rounded,
                    size: 34, color: AppColors.primary),
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
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A centered "or" between two hairline rules.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: SizedBox(height: 1, child: ColoredBox(color: AppColors.borderSubtle)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AppLocalizations.of(context)!.commonOr,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        const Expanded(
          child: SizedBox(height: 1, child: ColoredBox(color: AppColors.borderSubtle)),
        ),
      ],
    );
  }
}
