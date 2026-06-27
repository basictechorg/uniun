import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/widgets/group_entry_chooser.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/l10n/app_localizations.dart';

class GroupEntryPage extends StatelessWidget {
  const GroupEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GroupEntryChooser(
      title: l10n.groupEntryTitle,
      subtitle: l10n.groupEntrySubtitle,
      joinLabel: l10n.groupEntryJoin,
      createLabel: l10n.groupEntryCreate,
      onJoin: () => context.pushReplacementNamed(AppRoutes.joinGroup),
      onCreate: () => context.pushReplacementNamed(AppRoutes.createGroup),
    );
  }
}
