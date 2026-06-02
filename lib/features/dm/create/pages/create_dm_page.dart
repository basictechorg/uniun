import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/common/widgets/relay_selector_field.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/dm/create/bloc/create_dm_bloc.dart';

class CreateDmPage extends StatelessWidget {
  const CreateDmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CreateDmBloc>()..add(LoadRelaysEvent()),
      child: const _CreateDmView(),
    );
  }
}

class _CreateDmView extends StatefulWidget {
  const _CreateDmView();

  @override
  State<_CreateDmView> createState() => _CreateDmViewState();
}

class _CreateDmViewState extends State<_CreateDmView> {
  final _pubkeyController = TextEditingController();
  final List<String> _selectedRelays = [];
  bool _appliedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedArgs) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _appliedArgs = true;
      _pubkeyController.text = args;
    } else if (args is UniunQrPayload && args.kind == UniunQrKind.user) {
      _appliedArgs = true;
      _pubkeyController.text = args.id;
      _selectedRelays
        ..clear()
        ..addAll(args.relays);
    }
  }

  @override
  void dispose() {
    _pubkeyController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<CreateDmBloc>().add(
      SubmitDmEvent(
        otherPubkey: _pubkeyController.text,
        selectedRelays: _selectedRelays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateDmBloc, CreateDmState>(
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
           final pubkey = _pubkeyController.text.trim();
           Navigator.pop(context); // Pop creation screen
           Navigator.pushNamed(context, AppRoutes.chatDm, arguments: pubkey);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'New Message',
            style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: BlocBuilder<CreateDmBloc, CreateDmState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recipient Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _pubkeyController,
                    decoration: InputDecoration(
                      labelText: 'Recipient Public Key (hex or npub)',
                      labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text('Relays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Select the relays this message should be sent through.',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  
                  RelaySelectorField(
                    selected: _selectedRelays,
                    onChanged: (next) =>
                        setState(() => _selectedRelays
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Start Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
