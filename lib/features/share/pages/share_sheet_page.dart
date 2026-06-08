import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/features/share/bloc/share_sheet_bloc.dart';
import 'package:uniun/features/share/widgets/collapsible_section.dart';
import 'package:uniun/features/share/widgets/destination_tile.dart';
import 'package:uniun/features/share/widgets/dm_destination_tile.dart';
import 'package:uniun/l10n/app_localizations.dart';

class ShareSheetPage extends StatelessWidget {
  const ShareSheetPage({super.key, required this.sourceEventId});

  final String sourceEventId;

  static Future<void> show(BuildContext context, String sourceEventId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ShareSheetPage(sourceEventId: sourceEventId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ShareSheetBloc>()
        ..add(const ShareSheetEvent.loadDestinations()),
      child: KeyboardDismissOnTap(
        child: _ShareSheetView(sourceEventId: sourceEventId),
      ),
    );
  }
}

class _ShareSheetView extends StatelessWidget {
  const _ShareSheetView({required this.sourceEventId});
  final String sourceEventId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<ShareSheetBloc, ShareSheetState>(
      listenWhen: (a, b) => a.submitted != b.submitted || a.error != b.error,
      listener: (context, state) {
        if (state.submitted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.shareSuccess)),
          );
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<ShareSheetBloc>();
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.shareSheetTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      enabled: !state.submitting,
                      maxLength: 280,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: l10n.shareSheetCommentHint,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (v) =>
                          bloc.add(ShareSheetEvent.commentChanged(v)),
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: state.loading
                        ? const Center(child: CircularProgressIndicator())
                        : _DestinationList(
                            state: state,
                            scrollController: scrollController,
                            onPick: (dest) => bloc.add(
                              ShareSheetEvent.submit(
                                sourceEventId: sourceEventId,
                                destination: dest,
                              ),
                            ),
                          ),
                  ),
                  if (state.submitting)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

}

class _DestinationList extends StatelessWidget {
  const _DestinationList({
    required this.state,
    required this.scrollController,
    required this.onPick,
  });

  final ShareSheetState state;
  final ScrollController scrollController;
  final ValueChanged<ShareDestination> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        DestinationTile(
          icon: Icons.dynamic_feed_rounded,
          title: l10n.shareDestFeed,
          subtitle: l10n.shareDestFeedSubtitle,
          onTap: () => onPick(const ShareDestination.feed()),
        ),
        if (state.publicChannels.isNotEmpty)
          CollapsibleSection(
            label: l10n.shareSectionPublicChannels,
            child: Column(
              children: state.publicChannels
                  .map(
                    (c) => DestinationTile(
                      icon: Icons.tag_rounded,
                      title: c.name,
                      subtitle: c.about.isEmpty ? null : c.about,
                      onTap: () => onPick(
                        ShareDestination.publicChannel(channelId: c.channelId),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (state.privateChannels.isNotEmpty)
          CollapsibleSection(
            label: l10n.shareSectionPrivateChannels,
            child: Column(
              children: state.privateChannels
                  .map(
                    (g) => DestinationTile(
                      icon: Icons.lock_outline,
                      title: g.name,
                      subtitle: g.description.isEmpty ? null : g.description,
                      onTap: () => onPick(
                        ShareDestination.privateChannel(groupId: g.groupId),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        CollapsibleSection(
          label: l10n.shareSectionDms,
          child: state.dmConversations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.shareNoDmConversations,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: state.dmConversations
                      .map(
                        (d) => DmDestinationTile(
                          otherPubkeyHex: d.otherPubkey,
                          onTap: () => onPick(
                            ShareDestination.dm(otherPubkeyHex: d.otherPubkey),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
