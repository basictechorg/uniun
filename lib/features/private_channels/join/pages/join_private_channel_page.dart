import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
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
            elevation: 0,
            leading: UniunBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.joinPrivateChannelTitle,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          body: BlocBuilder<JoinPrivateChannelBloc, JoinPrivateChannelState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.joinPrivateChannelHeading,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.joinPrivateChannelSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _groupIdController,
                      decoration: InputDecoration(
                        labelText: l10n.joinPrivateChannelGroupIdLabel,
                        hintText: l10n.joinPrivateChannelGroupIdHint,
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
                    const SizedBox(height: 16),
                    RelaySelectorField(
                      selected: _selectedRelays,
                      onChanged: (next) => setState(() => _selectedRelays
                        ..clear()
                        ..addAll(next)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: state.isSubmitting
                            ? null
                            : () => context.pushNamed(AppRoutes.scanQr),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(l10n.joinPrivateChannelScanQr),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submit,
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
                                l10n.joinPrivateChannelAction,
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
