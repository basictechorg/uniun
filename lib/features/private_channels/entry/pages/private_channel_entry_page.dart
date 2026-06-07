import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/widgets/channel_entry_chooser.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/l10n/app_localizations.dart';

class PrivateChannelEntryPage extends StatelessWidget {
  const PrivateChannelEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChannelEntryChooser(
      title: l10n.privateChannelEntryTitle,
      subtitle: l10n.privateChannelEntrySubtitle,
      joinLabel: l10n.privateChannelEntryJoin,
      createLabel: l10n.privateChannelEntryCreate,
      icon: Icons.lock_outline_rounded,
      onJoin: () => context.pushReplacementNamed(AppRoutes.joinPrivateChannel),
      onCreate: () =>
          context.pushReplacementNamed(AppRoutes.createPrivateChannel),
    );
  }
}
