import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/features/channels/create/bloc/create_channel_bloc.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/relay_selector_field.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/settings/widgets/section_label.dart';
import 'package:uniun/l10n/app_localizations.dart';

class CreateChannelPage extends StatelessWidget {
  const CreateChannelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CreateChannelBloc>()..add(LoadRelaysEvent()),
      child: const _CreateChannelView(),
    );
  }
}

class _CreateChannelView extends StatefulWidget {
  const _CreateChannelView();

  @override
  State<_CreateChannelView> createState() => _CreateChannelViewState();
}

class _CreateChannelViewState extends State<_CreateChannelView> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();

  final List<String> _selectedRelays = [];

  bool _relaysExpanded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<CreateChannelBloc>().add(
      SubmitChannelEvent(
        name: _nameController.text,
        about: _aboutController.text,
        // Channel image is not collected in v1 — created without a picture.
        picture: '',
        selectedRelays: _selectedRelays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<CreateChannelBloc, CreateChannelState>(
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
              content: Text(l10n.createChannelSuccess),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: UniunBackButton(
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.createChannelHeaderTitle,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(
                height: 1, thickness: 1, color: AppColors.borderSubtle),
          ),
        ),
        body: KeyboardDismissOnTap(
          child: BlocBuilder<CreateChannelBloc, CreateChannelState>(
            builder: (context, state) => _buildCreateForm(state, l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateForm(CreateChannelState state, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Channel icon (decorative) ─────────────────────────────────────
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.tag_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Name ──────────────────────────────────────────────────────────
          SettingsSectionLabel(l10n.createChannelNameLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 30,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: l10n.createChannelNamePlaceholder,
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),

          // ── Description ───────────────────────────────────────────────────
          SettingsSectionLabel(l10n.createChannelDescriptionLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _aboutController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.createChannelAboutPlaceholder,
            ),
          ),
          const SizedBox(height: 20),

          // ── Permanence note ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.createChannelPermanenceNote,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Advanced · relays (collapsible) ───────────────────────────────
          InkWell(
            onTap: () =>
                setState(() => _relaysExpanded = !_relaysExpanded),
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.dns_rounded,
                      size: 20, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.createChannelAdvancedRelays,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _relaysExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.neutral400),
                  ),
                ],
              ),
            ),
          ),
          if (_relaysExpanded) ...[
            const SizedBox(height: 4),
            Text(
              l10n.createChannelPublishRelaysBody,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            RelaySelectorField(
              selected: _selectedRelays,
              onChanged: (next) => setState(() => _selectedRelays
                ..clear()
                ..addAll(next)),
            ),
          ],

          const SizedBox(height: 40),

          // ── Create (bottom CTA) ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: state.isSubmitting ? null : _onSubmit,
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
                      child: DropLoadingIndicator(
                        size: 20,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      l10n.createChannelAction,
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
  }
}
