import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/channels/create/bloc/create_channel_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
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

  void _showRelaySelectorDialog(List<String> availableRelays) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerLowest,
              title: const Text(
                'Select Relays',
                style: TextStyle(color: AppColors.onSurface),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableRelays.length,
                  itemBuilder: (context, index) {
                    final relay = availableRelays[index];
                    final isSelected = _selectedRelays.contains(relay);
                    return CheckboxListTile(
                      activeColor: AppColors.primary,
                      title: Text(relay, style: const TextStyle(fontSize: 14)),
                      value: isSelected,
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            _selectedRelays.add(relay);
                          } else {
                            _selectedRelays.remove(relay);
                          }
                        });
                        setState(() {}); // Update background UI
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            );
          },
        );
      },
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
            const SnackBar(
              content: Text('Success!'),
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
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Channel',
              style: TextStyle(
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
          const Text(
            'Channel Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: 'Channel Name',
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
              labelText: 'About (Theme/Rules)',
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
              labelText: 'Picture URL (Optional)',
              labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Text(
            'Publish Relays',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the relays this channel should be broadcasted on.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
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
                            ? 'Select Relays'
                            : '${_selectedRelays.length} Relays Selected',
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
              padding: const EdgeInsets.only(top: 12.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedRelays
                    .map(
                      (r) => Chip(
                        label: Text(r, style: const TextStyle(fontSize: 11)),
                        onDeleted: () {
                          setState(() {
                            _selectedRelays.remove(r);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
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
                  : const Text(
                      'Create Channel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.joinChannel),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n.joinChannelAction),
            ),
          ),
        ],
      ),
    );
  }
}
