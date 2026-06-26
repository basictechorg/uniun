import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Settings → About version row. Reads the real version + build number baked
/// from `pubspec.yaml` at build time (via package_info_plus) so it never drifts
/// from a hardcoded string.
class AppVersionRow extends StatefulWidget {
  const AppVersionRow({super.key});

  @override
  State<AppVersionRow> createState() => _AppVersionRowState();
}

class _AppVersionRowState extends State<AppVersionRow> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = 'v${info.version} (${info.buildNumber})');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsRow(
      icon: Icons.info_outline_rounded,
      label: l10n.settingsVersion,
      value: _version ?? '…',
      valueMono: true,
      showChevron: false,
    );
  }
}
