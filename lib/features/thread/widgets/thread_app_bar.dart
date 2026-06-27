import 'package:flutter/material.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/share/pages/share_sheet_page.dart';

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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share,
                    color: AppColors.onSurfaceVariant),
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
