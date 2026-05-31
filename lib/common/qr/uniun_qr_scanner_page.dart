import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Universal QR scanner. Decodes any [UniunQrPayload] and dispatches:
///   - user           → CreateDmPage (npub prefilled as a String argument)
///   - publicChannel  → JoinChannelPage (UniunQrPayload argument)
///   - privateChannel → JoinPrivateChannelPage (UniunQrPayload argument)
class UniunQrScannerPage extends StatefulWidget {
  const UniunQrScannerPage({super.key});

  @override
  State<UniunQrScannerPage> createState() => _UniunQrScannerPageState();
}

class _UniunQrScannerPageState extends State<UniunQrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _handled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleRaw(String raw) {
    if (_handled) return;
    final UniunQrPayload payload;
    try {
      payload = UniunQrPayload.decode(raw);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid QR: ${e is FormatException ? e.message : e}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _handled = true;

    final route = switch (payload.kind) {
      UniunQrKind.user => AppRoutes.createDm,
      UniunQrKind.publicChannel => AppRoutes.joinChannel,
      UniunQrKind.privateChannel => AppRoutes.joinPrivateChannel,
    };
    final args = payload.kind == UniunQrKind.user ? payload.id : payload;
    Navigator.of(context).pushReplacementNamed(route, arguments: args);
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    final capture = await _scannerController.analyzeImage(image.path);
    if (!mounted) return;
    final raw = capture?.barcodes.isEmpty ?? true
        ? null
        : capture!.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code found in the selected image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _handleRaw(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR'),
        actions: [
          IconButton(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Pick from gallery',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_handled) return;
              final raw = capture.barcodes.isEmpty
                  ? null
                  : capture.barcodes.first.rawValue?.trim();
              if (raw == null || raw.isEmpty) return;
              _handleRaw(raw);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Scan a UNIUN QR — user, public channel, or private channel',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
