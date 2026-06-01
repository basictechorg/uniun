import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/channel_entry_chooser.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/l10n/app_localizations.dart';

class ChannelEntryPage extends StatelessWidget {
  const ChannelEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChannelEntryChooser(
      title: l10n.channelEntryTitle,
      subtitle: l10n.channelEntrySubtitle,
      joinLabel: l10n.channelEntryJoin,
      createLabel: l10n.channelEntryCreate,
      onJoin: () => Navigator.pushReplacementNamed(
        context,
        AppRoutes.joinChannel,
      ),
      onCreate: () => Navigator.pushReplacementNamed(
        context,
        AppRoutes.createChannel,
      ),
    );
  }
}
