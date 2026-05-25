import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/private_channels/join/bloc/join_private_channel_bloc.dart';
import 'package:uniun/core/router/app_routes.dart';

class JoinPrivateChannelPage extends StatelessWidget {
  const JoinPrivateChannelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<JoinPrivateChannelBloc>(),
      child: const _JoinPrivateChannelView(),
    );
  }
}

class _JoinPrivateChannelView extends StatefulWidget {
  const _JoinPrivateChannelView();

  @override
  State<_JoinPrivateChannelView> createState() => _JoinPrivateChannelViewState();
}

class _JoinPrivateChannelViewState extends State<_JoinPrivateChannelView> {
  final _groupIdController = TextEditingController();
  final _relayController = TextEditingController();

  @override
  void dispose() {
    _groupIdController.dispose();
    _relayController.dispose();
    super.dispose();
  }

  void _submit() {
    final groupId = _groupIdController.text.trim();
    if (groupId.isEmpty) return;

    final relaysText = _relayController.text.trim();
    final relays = relaysText.isEmpty
        ? <String>[]
        : relaysText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    context.read<JoinPrivateChannelBloc>().add(
      SubmitJoinPrivateChannelEvent(groupId: groupId, relays: relays),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            const SnackBar(
              content: Text("Join request sent! Wait for admin approval."),
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
            title: const Text(
              "Join Private Channel",
              style: TextStyle(
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
                    const Text(
                      "Request to Join",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Enter the Group ID to request access to a private channel.",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _groupIdController,
                      decoration: InputDecoration(
                        labelText: "Group ID",
                        hintText: "uniun'...",
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
                    TextField(
                      controller: _relayController,
                      decoration: InputDecoration(
                        labelText: 'Relays (comma separated)',
                        hintText: 'wss://relay1.com, wss://relay2.com',
                        helperText: 'Where to send the join request',
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
                            : const Text(
                                "Send Join Request",
                                style: TextStyle(
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
