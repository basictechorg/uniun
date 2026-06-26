import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Full-screen camera scanner used by the import-identity page's
/// "Scan a QR instead" action. Pops the raw scanned string back to the caller,
/// which feeds it into the existing import flow — exactly like a clipboard
/// paste. Unlike [UniunQrScannerPage], this does not decode UNIUN payloads; the
/// QR is expected to carry a private key (nsec / hex).
class KeyQrScannerPage extends StatefulWidget {
  const KeyQrScannerPage({super.key});

  @override
  State<KeyQrScannerPage> createState() => _KeyQrScannerPageState();
}

class _KeyQrScannerPageState extends State<KeyQrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: const UniunBackButton(color: Colors.white),
        title: Text(l10n.importScanTitle),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.importScanHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
