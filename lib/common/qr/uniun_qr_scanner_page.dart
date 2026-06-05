import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/pubkey_normalizer.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';
import 'package:uniun/features/profile/pages/user_profile_page.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Universal QR scanner. Decodes any [UniunQrPayload] and dispatches:
///   - user           → see [UniunQrScanIntent] (profile / auto-follow / auto-dm)
///   - publicChannel  → JoinChannelPage (UniunQrPayload argument)
///   - privateChannel → JoinPrivateChannelPage (UniunQrPayload argument)
///
/// Intent is read from the route argument and only affects user QRs:
///   - [generic]: open the user's profile page.
///   - [follow]:  run Follow directly, snackbar + pop.
///   - [dm]:      open CreateDmPage prefilled.
enum UniunQrScanIntent { generic, follow, dm }

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

  Future<void> _handleRaw(String raw) async {
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

    await _ensureRelaysPresent(payload.relays);
    if (!mounted) return;

    final intent = ModalRoute.of(context)?.settings.arguments;

    if (payload.kind == UniunQrKind.user) {
      await _dispatchUser(payload, intent);
      return;
    }

    final route = switch (payload.kind) {
      UniunQrKind.user => AppRoutes.userProfile, // unreachable, handled above
      UniunQrKind.publicChannel => AppRoutes.joinChannel,
      UniunQrKind.privateChannel => AppRoutes.joinPrivateChannel,
    };
    Navigator.of(context).pushReplacementNamed(route, arguments: payload);
  }

  Future<void> _dispatchUser(UniunQrPayload payload, Object? intent) async {
    if (intent == UniunQrScanIntent.dm) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.createDm,
        arguments: payload,
      );
      return;
    }

    final String hex;
    try {
      hex = normalizeNostrPubkey(payload.id);
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.followActionInvalidKey)),
      );
      Navigator.of(context).pop();
      return;
    }

    if (intent == UniunQrScanIntent.follow) {
      final result = await getIt<FollowUserUseCase>().call(
        FollowUserInput(pubkeyHex: hex, petname: payload.name),
      );
      if (!mounted) return;
      result.fold(
        (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.toString())),
        ),
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.followActionSuccess)),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.userProfile,
      arguments: UserProfileArgs(pubkeyHex: hex, hintName: payload.name),
    );
  }

  /// Add any scanned relay we don't already have to the local relay list, so
  /// the user can join/DM seamlessly without manual setup.
  Future<void> _ensureRelaysPresent(List<String> relays) async {
    if (relays.isEmpty) return;
    final existing = await getIt<GetRelaysUseCase>().call();
    final known = existing.fold(
      (_) => <String>{},
      (list) => list.map((r) => r.url).toSet(),
    );
    final save = getIt<SaveRelayUseCase>();
    for (final url in relays) {
      if (url.isEmpty || known.contains(url)) continue;
      await save.call(url);
    }
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
