import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/widgets/group_entry_chooser.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/l10n/app_localizations.dart';

class PrivateGroupEntryPage extends StatelessWidget {
  const PrivateGroupEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GroupEntryChooser(
      title: l10n.privateGroupEntryTitle,
      subtitle: l10n.privateGroupEntrySubtitle,
      joinLabel: l10n.privateGroupEntryJoin,
      createLabel: l10n.privateGroupEntryCreate,
      icon: Icons.lock_outline_rounded,
      onJoin: () => context.pushReplacementNamed(AppRoutes.joinPrivateGroup),
      onCreate: () =>
          context.pushReplacementNamed(AppRoutes.createPrivateGroup),
    );
  }
}
