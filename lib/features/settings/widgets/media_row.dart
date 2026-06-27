import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Settings → Storage row that pushes to the Media gallery (file manager).
class MediaRow extends StatelessWidget {
  const MediaRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsRow(
      icon: Icons.photo_library_outlined,
      label: l10n.storageMediaRow,
      subtitle: l10n.storageMediaRowSubtitle,
      onTap: () => context.pushNamed(AppRoutes.mediaGallery),
    );
  }
}
