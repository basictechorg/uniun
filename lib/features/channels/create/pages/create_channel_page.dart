import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/features/channels/create/bloc/create_channel_bloc.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/relay_selector_field.dart';
import 'package:uniun/core/theme/app_theme.dart';
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
  final _pictureController = TextEditingController();

  final List<String> _selectedRelays = [];

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _pictureController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<CreateChannelBloc>().add(
      SubmitChannelEvent(
        name: _nameController.text,
        about: _aboutController.text,
        picture: _pictureController.text,
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
              backgroundColor: Colors.green,
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
            leading: UniunBackButton(
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              l10n.createChannelTitle,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          body: KeyboardDismissOnTap(
            child: BlocBuilder<CreateChannelBloc, CreateChannelState>(
              builder: (context, state) {
                return _buildCreateTab(state, l10n);
              },
            ),
          ),
        ),
    );
  }

  Widget _buildCreateTab(CreateChannelState state, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.createChannelDetailsHeading,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: l10n.createChannelNameLabel,
              labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
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
            controller: _aboutController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.createChannelAboutLabel,
              labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _pictureController,
            decoration: InputDecoration(
              labelText: l10n.createChannelPictureLabel,
              labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 32),
          Text(
            l10n.createChannelPublishRelays,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.createChannelPublishRelaysBody,
            style: const TextStyle(
                fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          RelaySelectorField(
            selected: _selectedRelays,
            onChanged: (next) => setState(() => _selectedRelays
              ..clear()
              ..addAll(next)),
          ),

          const SizedBox(height: 48),

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
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
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
