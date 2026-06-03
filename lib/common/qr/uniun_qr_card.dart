import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/core/router/deep_link.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Shared QR display dialog used for all three sharing kinds. Render via
/// `showDialog(builder: (_) => UniunQrCard.xxx(...))`. Always copies the FULL
/// underlying id to the clipboard — never a truncated display string.
class UniunQrCard extends StatefulWidget {
  const UniunQrCard._({
    required this.entries,
    required this.titleLeading,
  });

  /// Tabs/entries shown in the card. Single-entry cards render without a
  /// toggle; multi-entry cards (DM) show a [ToggleButtons] header.
  // ignore: library_private_types_in_public_api
  final List<_QrEntry> entries;
  final Widget? titleLeading;

  /// User identity card (own or anyone else's).
  factory UniunQrCard.user({
    required String npub,
    String? name,
    List<String> relays = const [],
  }) {
    return UniunQrCard._(
      titleLeading: null,
      entries: [
        _QrEntry(
          label: name ?? 'User',
          subtitle: npub,
          copyValue: npub,
          payload: UniunQrPayload(
            kind: UniunQrKind.user,
            id: npub,
            name: name,
            relays: relays,
          ),
          copyLabel: 'Copy npub',
        ),
      ],
    );
  }

  /// Public channel card.
  factory UniunQrCard.publicChannel({
    required String name,
    required String channelId,
    required List<String> relays,
  }) {
    return UniunQrCard._(
      titleLeading: const Icon(
        Icons.tag_rounded,
        size: 18,
        color: AppColors.primary,
      ),
      entries: [
        _QrEntry(
          label: name,
          subtitle: channelId,
          copyValue: channelId,
          payload: UniunQrPayload(
            kind: UniunQrKind.publicChannel,
            id: channelId,
            name: name,
            relays: relays,
          ),
          copyLabel: 'Copy channel ID',
        ),
      ],
    );
  }

  /// Private channel card.
  factory UniunQrCard.privateChannel({
    required String name,
    required String groupId,
    required List<String> relays,
  }) {
    return UniunQrCard._(
      titleLeading: const Icon(
        Icons.lock_outline,
        size: 18,
        color: AppColors.primary,
      ),
      entries: [
        _QrEntry(
          label: name,
          subtitle: groupId,
          copyValue: groupId,
          payload: UniunQrPayload(
            kind: UniunQrKind.privateChannel,
            id: groupId,
            name: name,
            relays: relays,
          ),
          copyLabel: 'Copy group ID',
        ),
      ],
    );
  }

  /// DM-chat card with a "Their key | My key" toggle. Both branches encode
  /// a [UniunQrKind.user] payload. [conversationRelays] are the relays this DM
  /// is configured to use; they ride along in the QR so the scanner can
  /// auto-add them on the receiver's device.
  factory UniunQrCard.dmConversation({
    required String partnerNpub,
    String? partnerName,
    required String myNpub,
    String? myName,
    List<String> conversationRelays = const [],
  }) {
    return UniunQrCard._(
      titleLeading: null,
      entries: [
        _QrEntry(
          label: partnerName ?? 'Their key',
          subtitle: partnerNpub,
          copyValue: partnerNpub,
          payload: UniunQrPayload(
            kind: UniunQrKind.user,
            id: partnerNpub,
            name: partnerName,
            relays: conversationRelays,
          ),
          copyLabel: 'Copy npub',
          tabLabel: 'Their key',
        ),
        _QrEntry(
          label: myName ?? 'Your key',
          subtitle: myNpub,
          copyValue: myNpub,
          payload: UniunQrPayload(
            kind: UniunQrKind.user,
            id: myNpub,
            name: myName,
            relays: conversationRelays,
          ),
          copyLabel: 'Copy npub',
          tabLabel: 'My key',
        ),
      ],
    );
  }

  @override
  // ignore: library_private_types_in_public_api
  State<UniunQrCard> createState() => _UniunQrCardState();
}

class _UniunQrCardState extends State<UniunQrCard> {
  int _selected = 0;

  /// Wraps the white QR box so it can be captured to a PNG for sharing. Only
  /// the selected entry's QR is in the tree at a time, so one key suffices.
  final GlobalKey _qrBoundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final entry = widget.entries[_selected];
    final hasToggle = widget.entries.length > 1;
    final shortSubtitle = _truncateMiddle(entry.subtitle, 12);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasToggle) ...[
              _ToggleHeader(
                labels: [
                  for (final e in widget.entries) e.tabLabel ?? e.label,
                ],
                selectedIndex: _selected,
                onChanged: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.titleLeading != null) ...[
                  widget.titleLeading!,
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    entry.label,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              shortSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: RepaintBoundary(
                key: _qrBoundaryKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: entry.payload.encode(),
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _shareEntry(entry),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(AppLocalizations.of(context)!.qrShareAction),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                // Always copy the FULL id — never the truncated display.
                Clipboard.setData(ClipboardData(text: entry.copyValue));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text('${entry.copyLabel} • copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                entry.copyLabel,
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Captures the on-screen QR box as a PNG and opens the native share sheet
  /// with the image + the entity's deep link as text. Works for every card
  /// kind (user / public / private channel) via [_deepLinkFor].
  Future<void> _shareEntry(_QrEntry entry) async {
    // Anchor the iPad share popover to this card — read before any await.
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    File? file;
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      // 2.0 keeps the QR crisp and scannable while rasterising ~4x fewer
      // pixels than 3.0.
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      // Fixed filename — overwritten each share, so temp files never pile up.
      file = await File('${dir.path}/uniun_qr_share.png').writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _deepLinkFor(entry.payload).toString(),
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.qrShareFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // Best-effort cleanup once the share sheet has taken the bytes.
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// Maps a QR payload to its shareable `https://www.uniun.in/...` deep link.
  Uri _deepLinkFor(UniunQrPayload p) => switch (p.kind) {
        UniunQrKind.user =>
          DeepLink.user(p.id, relays: p.relays),
        UniunQrKind.publicChannel =>
          DeepLink.channel(p.id, name: p.name, relays: p.relays),
        UniunQrKind.privateChannel =>
          DeepLink.privateChannel(p.id, name: p.name, relays: p.relays),
      };

  String _truncateMiddle(String s, int side) {
    if (s.length <= side * 2 + 3) return s;
    return '${s.substring(0, side)}…${s.substring(s.length - side)}';
  }
}

class _QrEntry {
  const _QrEntry({
    required this.label,
    required this.subtitle,
    required this.copyValue,
    required this.payload,
    required this.copyLabel,
    this.tabLabel,
  });
  final String label;
  final String subtitle;
  final String copyValue;
  final UniunQrPayload payload;
  final String copyLabel;
  final String? tabLabel;
}

class _ToggleHeader extends StatelessWidget {
  const _ToggleHeader({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selectedIndex == i
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
