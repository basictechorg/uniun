import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/common/widgets/composer/reference_picker_page.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/features/receive_share/bloc/receive_share_bloc.dart';
import 'package:uniun/features/receive_share/widgets/shared_incoming.dart';
import 'package:uniun/features/share/widgets/collapsible_section.dart';
import 'package:uniun/features/share/widgets/destination_tile.dart';
import 'package:uniun/features/share/widgets/dm_destination_tile.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Landing surface for content shared INTO UNIUN from another app.
///
/// Pre-fills the composer with the shared text/media, shows the drawer-style
/// destination list (Feed / Public channels / Private channels / DMs), and
/// offers "Save to draft". Reuses the outbound share widgets so the picker
/// looks identical; publishing goes through [ReceiveShareBloc] (Brahma path).
class ReceiveShareSheetPage extends StatelessWidget {
  const ReceiveShareSheetPage({super.key, required this.incoming});

  final SharedIncoming incoming;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<ReceiveShareBloc>()..add(ReceiveShareEvent.init(incoming)),
      child: _ReceiveShareView(incoming: incoming),
    );
  }
}

class _ReceiveShareView extends StatefulWidget {
  const _ReceiveShareView({required this.incoming});
  final SharedIncoming incoming;

  @override
  State<_ReceiveShareView> createState() => _ReceiveShareViewState();
}

class _ReceiveShareViewState extends State<_ReceiveShareView> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.incoming.text ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          l10n.receiveShareTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: BlocConsumer<ReceiveShareBloc, ReceiveShareState>(
        listenWhen: (a, b) =>
            a.submitted != b.submitted ||
            a.draftSaved != b.draftSaved ||
            a.error != b.error,
        listener: (context, state) {
          if (state.submitted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.shareSuccess)),
            );
          } else if (state.draftSaved) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.receiveShareDraftSaved)),
            );
          } else if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_errorText(l10n, state.error!))),
            );
          }
        },
        builder: (context, state) {
          final bloc = context.read<ReceiveShareBloc>();
          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: UniunComposer(
                    controller: _controller,
                    focusNode: _focusNode,
                    avatarSeed: state.authorPubkey,
                    hintText: l10n.receiveShareCommentHint,
                    minLines: 3,
                    maxLines: 8,
                    applyBottomInset: false,
                    markdownEnabled: true,
                    onTextChanged: (v) =>
                        bloc.add(ReceiveShareEvent.contentChanged(v)),
                    references: state.references,
                    onRemoveReference: (id) =>
                        bloc.add(ReceiveShareEvent.removeReference(id)),
                    onAddReference: () => _pickReferences(context, bloc, state),
                    attachments: state.pending,
                    onRemoveAttachment: (sha) =>
                        bloc.add(ReceiveShareEvent.removeMedia(sha)),
                    onAttachMedia: () => _pickMedia(context, bloc, state),
                    isAttachingMedia: state.ingesting,
                    onDraft: () => bloc.add(const ReceiveShareEvent.saveToDraft()),
                    draftLabel: l10n.receiveShareSaveDraft,
                  ),
                ),
                if (state.ingesting)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      l10n.receiveShareIngesting,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                const Divider(height: 24),
                Expanded(
                  child: state.loading
                      ? const Center(child: DropLoadingIndicator())
                      : _DestinationList(
                          state: state,
                          onPick: (dest) =>
                              bloc.add(ReceiveShareEvent.submit(dest)),
                        ),
                ),
                if (state.submitting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Maps the bloc's internal error sentinels to localized copy; other errors
  /// (failures) pass through as-is.
  String _errorText(AppLocalizations l10n, String error) {
    switch (error) {
      case 'draft-needs-text':
        return l10n.receiveShareDraftNeedsText;
      case 'nothing-to-share':
        return l10n.receiveShareNothingToShare;
      default:
        return error;
    }
  }

  Future<void> _pickReferences(
    BuildContext context,
    ReceiveShareBloc bloc,
    ReceiveShareState state,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.of(context).push<List<ComposerReference>>(
      MaterialPageRoute(
        builder: (_) => ReferencePickerPage(
          title: l10n.composerReferenceTitle,
          searchHint: l10n.composerReferenceSearchHint,
          emptyLabel: l10n.composerReferenceEmpty,
          initialSelected: state.references,
        ),
      ),
    );
    if (result != null) bloc.add(ReceiveShareEvent.setReferences(result));
  }

  Future<void> _pickMedia(
    BuildContext context,
    ReceiveShareBloc bloc,
    ReceiveShareState state,
  ) async {
    if (state.ingesting) return;
    final picked = await showMediaPickSheet(context);
    if (picked == null) return;
    bloc.add(ReceiveShareEvent.attachMedia(picked));
  }
}

class _DestinationList extends StatelessWidget {
  const _DestinationList({required this.state, required this.onPick});

  final ReceiveShareState state;
  final ValueChanged<ShareDestination> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Text(
            l10n.shareToLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
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
