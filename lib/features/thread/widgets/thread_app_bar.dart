import 'package:flutter/material.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/core/theme/app_custom_colors.dart';
import 'package:uniun/features/share/pages/share_sheet_page.dart';
import 'package:uniun/l10n/app_localizations.dart';

class ThreadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ThreadAppBar({super.key, this.sourceEventId});

  /// The note this thread is anchored on. When null (loading / error states,
  /// before the root resolves) the share action is disabled.
  final String? sourceEventId;

  @override
  Size get preferredSize {
    // Include status-bar height so the Scaffold body starts below both
    // the status bar and the toolbar — prevents content overlapping the notch.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final statusBarHeight = view.padding.top / view.devicePixelRatio;
    return Size.fromHeight(kToolbarHeight + statusBarHeight);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final custom = context.custom;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: custom.borderSubtle),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              UniunBackButton(
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.threadTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.ios_share,
                    color: colorScheme.onSurfaceVariant),
                onPressed: sourceEventId == null
                    ? null
                    : () => ShareSheetPage.show(context, sourceEventId!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
