import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/common/qr/uniun_qr_scanner_page.dart';
import 'package:uniun/common/widgets/relay_selector_field.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/dm/create/bloc/create_dm_bloc.dart';

class CreateDmPage extends StatelessWidget {
  const CreateDmPage({super.key, this.initialPubkey, this.payload});

  /// Pre-filled recipient (npub/hex) — e.g. from a QR scan.
  final String? initialPubkey;
  final UniunQrPayload? payload;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CreateDmBloc>()..add(LoadRelaysEvent()),
      child: _CreateDmView(initialPubkey: initialPubkey, payload: payload),
    );
  }
}

class _CreateDmView extends StatefulWidget {
  const _CreateDmView({this.initialPubkey, this.payload});

  final String? initialPubkey;
  final UniunQrPayload? payload;

  @override
  State<_CreateDmView> createState() => _CreateDmViewState();
}

class _CreateDmViewState extends State<_CreateDmView> {
  final _pubkeyController = TextEditingController();
  final List<String> _selectedRelays = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPubkey;
    final payload = widget.payload;
    if (initial != null && initial.isNotEmpty) {
      _pubkeyController.text = initial;
    } else if (payload != null && payload.kind == UniunQrKind.user) {
      _pubkeyController.text = payload.id;
      _selectedRelays
        ..clear()
        ..addAll(payload.relays);
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

  void _scanByQr() {
    // The unified scanner replaces this page with a fresh CreateDmPage
    // pre-filled from the scanned user payload.
    context.pushNamed(AppRoutes.scanQr, extra: UniunQrScanIntent.dm);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateDmBloc, CreateDmState>(
      listener: (context, state) {
        // Relay pre-selection is handled by [RelaySelectorField], which
        // auto-selects the UNIUN backend relay when none is picked yet. A QR
        // payload that already carried relays is left untouched.
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
           // Replace the creation screen with the chat (route id may be hex
           // or npub — the chatDm route normalises it).
           context.pushReplacementNamed(
             AppRoutes.chatDm,
             pathParameters: {'id': pubkey},
           );
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

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: state.isSubmitting ? null : _scanByQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan QR Code'),
                    ),
                  ),

                  const SizedBox(height: 16),

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
