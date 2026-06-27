import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/relay_selector_field.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/private_channels/create/bloc/create_private_channel_bloc.dart';

class CreatePrivateChannelPage extends StatelessWidget {
  const CreatePrivateChannelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CreatePrivateChannelBloc>(),
      child: const _CreatePrivateChannelView(),
    );
  }
}

class _CreatePrivateChannelView extends StatefulWidget {
  const _CreatePrivateChannelView();

  @override
  State<_CreatePrivateChannelView> createState() => _CreatePrivateChannelViewState();
}

class _CreatePrivateChannelViewState extends State<_CreatePrivateChannelView> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<String> _selectedRelays = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    context.read<CreatePrivateChannelBloc>().add(
      SubmitCreatePrivateChannelEvent(
        name: name,
        description: _descController.text.trim(),
        relays: _selectedRelays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<CreatePrivateChannelBloc, CreatePrivateChannelState>(
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
              content: Text(l10n.createPrivateChannelSuccess),
              backgroundColor: AppColors.success,
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
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: UniunBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.createPrivateChannelTitle,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            bottom: const _HairlineBorder(),
          ),
          body: BlocBuilder<CreatePrivateChannelBloc, CreatePrivateChannelState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encrypted eyebrow — green, matching the DS SectionLabel.
                    _Eyebrow(
                      icon: Icons.lock_rounded,
                      label: l10n.createPrivateChannelEncrypted,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 20),

                    // Decorative encrypted emblem.
                    const Center(child: _LockEmblem()),
                    const SizedBox(height: 28),

                    // Name
                    _Eyebrow(label: l10n.createPrivateChannelNameLabel),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: l10n.createPrivateChannelNameHint,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    _Eyebrow(label: l10n.createPrivateChannelDescLabel),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.createPrivateChannelDescHint,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Relays
                    _Eyebrow(
                      icon: Icons.dns_rounded,
                      label: l10n.identityRelays,
                    ),
                    const SizedBox(height: 8),
                    RelaySelectorField(
                      selected: _selectedRelays,
                      onChanged: (next) => setState(() => _selectedRelays
                        ..clear()
                        ..addAll(next)),
                    ),
                    const SizedBox(height: 24),

                    // Encrypted info — success tint.
                    _EncryptedInfoCard(
                      text: l10n.createPrivateChannelDescription,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.createPrivateChannelAdminNote,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Primary action.
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                l10n.createPrivateChannelAction,
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

/// 1px hairline under the app bar (DS `border-subtle`).
class _HairlineBorder extends StatelessWidget implements PreferredSizeWidget {
  const _HairlineBorder();

  @override
  Size get preferredSize => const Size.fromHeight(1);

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.borderSubtle);
}

/// UPPERCASE wide-tracked eyebrow (DS `SectionLabel`): optional leading icon +
/// a tracked label. Defaults to the muted field-label treatment.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({
    required this.label,
    this.icon,
    this.color = AppColors.onSurfaceVariant,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Decorative 80×80 lock tile — the channel's encrypted identity.
class _LockEmblem extends StatelessWidget {
  const _LockEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.lock_rounded,
        size: 38,
        color: AppColors.primary,
      ),
    );
  }
}

/// Success-tinted info card explaining the encryption guarantee.
class _EncryptedInfoCard extends StatelessWidget {
  const _EncryptedInfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded, size: 20, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
