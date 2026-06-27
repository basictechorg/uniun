import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/common/widgets/composer/reference_picker_page.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/note_card/reference_note_card.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ShareSheetPage(sourceEventId: sourceEventId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ShareSheetBloc>()
        ..add(ShareSheetEvent.loadDestinations(sourceEventId)),
      child: KeyboardDismissOnTap(
        child: _ShareSheetView(sourceEventId: sourceEventId),
      ),
    );
  }
}

class _ShareSheetView extends StatefulWidget {
  const _ShareSheetView({required this.sourceEventId});
  final String sourceEventId;

  @override
  State<_ShareSheetView> createState() => _ShareSheetViewState();
}

class _ShareSheetViewState extends State<_ShareSheetView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

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
            initialChildSize: 0.72,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.shareSheetTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        if (state.quotedNote != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _QuotingCard(
                              key: ValueKey(state.quotedNote!.id),
                              note: state.quotedNote!,
                            ),
                          ),
                        // Reuse the canonical composer (no send button — the
                        // bottom Share button publishes the selected destination).
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: UniunComposer(
                            controller: _controller,
                            focusNode: _focusNode,
                            avatarSeed: state.authorPubkey,
                            hintText: l10n.shareSheetCommentHint,
                            minLines: 1,
                            maxLines: 4,
                            applyBottomInset: false,
                            onTextChanged: (v) =>
                                bloc.add(ShareSheetEvent.contentChanged(v)),
                            references: state.references,
                            onRemoveReference: (id) =>
                                bloc.add(ShareSheetEvent.removeReference(id)),
                            onAddReference: () =>
                                _pickReferences(context, bloc, state),
                            attachments: state.pending,
                            onRemoveAttachment: (sha) =>
                                bloc.add(ShareSheetEvent.removeMedia(sha)),
                            onAttachMedia: () => _pickMedia(context, bloc),
                            isAttachingMedia: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                          child: _SectionEyebrow(l10n.shareToLabel),
                        ),
                        if (state.loading)
                          const Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(child: DropLoadingIndicator()),
                          )
                        else
                          _DestinationList(
                            state: state,
                            onPick: (dest) => bloc
                                .add(ShareSheetEvent.selectDestination(dest)),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  _ShareBar(
                    enabled:
                        state.selectedDestination != null && !state.submitting,
                    submitting: state.submitting,
                    onShare: () => bloc.add(
                      ShareSheetEvent.submit(
                        sourceEventId: widget.sourceEventId,
                        destination: state.selectedDestination!,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickReferences(
      BuildContext context, ShareSheetBloc bloc, ShareSheetState state) async {
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
    if (result != null) bloc.add(ShareSheetEvent.setReferences(result));
  }

  Future<void> _pickMedia(BuildContext context, ShareSheetBloc bloc) async {
    final picked = await showMediaPickSheet(context);
    if (picked == null) return;
    bloc.add(ShareSheetEvent.attachMedia(picked));
  }
}

/// UPPERCASE wide-tracked eyebrow label (design-system `SectionLabel`).
class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

/// Quoted-note preview pinned at the top of the sheet — the embed-by-value
/// snapshot the user is sharing. Muted fill + a left primary accent bar.
class _QuotingCard extends StatefulWidget {
  const _QuotingCard({super.key, required this.note});
  final NoteEntity note;

  @override
  State<_QuotingCard> createState() => _QuotingCardState();
}

class _QuotingCardState extends State<_QuotingCard> {
  ProfileEntity? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await getIt<ProfileRepository>().getProfile(widget.note.authorPubkey);
    if (!mounted) return;
    setState(() => _profile = result.fold((_) => null, (p) => p));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: AppColors.primary),
            Expanded(
              child: Container(
                color: AppColors.surfaceLow,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionEyebrow(l10n.shareQuotingLabel),
                    const SizedBox(height: 8),
                    ReferenceNoteCard(note: widget.note, profile: _profile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned bottom CTA — publishes the currently selected destination.
class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.enabled,
    required this.submitting,
    required this.onShare,
  });

  final bool enabled;
  final bool submitting;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomSafe),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: enabled ? onShare : null,
          icon: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(l10n.shareActionShare),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.7),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _DestinationList extends StatelessWidget {
  const _DestinationList({required this.state, required this.onPick});

  final ShareSheetState state;
  final ValueChanged<ShareDestination> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = state.selectedDestination;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          DestinationTile(
            icon: Icons.dynamic_feed_rounded,
            title: l10n.shareDestFeed,
            subtitle: l10n.shareDestFeedSubtitle,
            selected: selected == const ShareDestination.feed(),
            onTap: () => onPick(const ShareDestination.feed()),
          ),
          if (state.publicGroups.isNotEmpty)
            CollapsibleSection(
              label: l10n.shareSectionPublicGroups,
              child: Column(
                children: state.publicGroups
                    .map(
                      (c) => DestinationTile(
                        icon: Icons.tag_rounded,
                        title: c.name,
                        subtitle: c.about.isEmpty ? null : c.about,
                        selected: selected ==
                            ShareDestination.publicGroup(
                                groupId: c.groupId),
                        onTap: () => onPick(
                          ShareDestination.publicGroup(groupId: c.groupId),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (state.privateGroups.isNotEmpty)
            CollapsibleSection(
              label: l10n.shareSectionPrivateGroups,
              child: Column(
                children: state.privateGroups
                    .map(
                      (g) => DestinationTile(
                        icon: Icons.lock_outline,
                        title: g.name,
                        subtitle: g.description.isEmpty ? null : g.description,
                        selected: selected ==
                            ShareDestination.privateGroup(groupId: g.groupId),
                        onTap: () => onPick(
                          ShareDestination.privateGroup(groupId: g.groupId),
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
                            selected: selected ==
                                ShareDestination.dm(
                                    otherPubkeyHex: d.otherPubkey),
                            onTap: () => onPick(
                              ShareDestination.dm(otherPubkeyHex: d.otherPubkey),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
