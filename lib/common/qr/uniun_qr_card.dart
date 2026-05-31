import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/core/theme/app_theme.dart';

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
  /// a [UniunQrKind.user] payload.
  factory UniunQrCard.dmConversation({
    required String partnerNpub,
    String? partnerName,
    required String myNpub,
    String? myName,
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
            const SizedBox(height: 16),
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
