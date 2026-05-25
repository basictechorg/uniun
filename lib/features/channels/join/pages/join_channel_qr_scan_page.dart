import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

class JoinChannelQrScanPage extends StatefulWidget {
  const JoinChannelQrScanPage({super.key});

  @override
  State<JoinChannelQrScanPage> createState() => _JoinChannelQrScanPageState();
}

class _JoinChannelQrScanPageState extends State<JoinChannelQrScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _handledScan = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _pickQrFromGallery() async {
    final l10n = AppLocalizations.of(context)!;
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    final capture = await _scannerController.analyzeImage(image.path);
    if (!mounted) return;

    final barcode = capture?.barcodes.isEmpty ?? true
        ? null
        : capture!.barcodes.first;
    final rawValue = barcode?.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.joinChannelQrGalleryError),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _handledScan = true;
    Navigator.of(context).pop(rawValue);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.joinChannelQrTitle),
        actions: [
          IconButton(
            onPressed: _pickQrFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: l10n.joinChannelQrFromGallery,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_handledScan) return;
              final barcode =
                  capture.barcodes.isEmpty ? null : capture.barcodes.first;
              final rawValue = barcode?.rawValue?.trim();
              if (rawValue == null || rawValue.isEmpty) return;
              _handledScan = true;
              Navigator.of(context).pop(rawValue);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.joinChannelQrHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
