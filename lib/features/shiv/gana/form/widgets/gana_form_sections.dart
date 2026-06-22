part of '../pages/gana_form_page.dart';

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.nameCtrl,
    required this.descCtrl,
    required this.taskCtrl,
    required this.userRefCtrl,
    required this.intervalCtrl,
    required this.maxOutputsCtrl,
  });

  final GanaFormState state;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController taskCtrl;
  final TextEditingController userRefCtrl;
  final TextEditingController intervalCtrl;
  final TextEditingController maxOutputsCtrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _FieldLabel(l10n.ganaFormNameLabel),
        const SizedBox(height: 6),
        TextField(
          controller: nameCtrl,
          decoration: _inputDeco(l10n.ganaFormNameHint),
          onChanged: (v) =>
              context.read<GanaFormBloc>().add(GanaFormNameChangedEvent(v)),
          maxLength: 60,
        ),
        const SizedBox(height: 12),
        _FieldLabel(l10n.ganaFormDescriptionLabel),
        const SizedBox(height: 6),
        TextField(
          controller: descCtrl,
          decoration: _inputDeco(l10n.ganaFormDescriptionHint),
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormDescriptionChangedEvent(v)),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        _SectionTitle(l10n.ganaFormManasSectionTitle),
        const SizedBox(height: 4),
        _SectionSubtitle(l10n.ganaFormManasSectionSubtitle),
        const SizedBox(height: 10),
        if (state.manases.isEmpty)
          _NoManasesCta()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in state.manases)
                FilterChip(
                  label: Text(m.name),
                  selected: state.selectedManasIds.contains(m.manasId),
                  onSelected: (_) => context
                      .read<GanaFormBloc>()
                      .add(GanaFormToggleManasEvent(m.manasId)),
                  showCheckmark: true,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                ),
              // "+ Create" trailing affordance — opens Brahma's Manas form
              // and reloads picker pools on return.
              ActionChip(
                avatar: const Icon(Icons.add, size: 16,
                    color: AppColors.primary),
                label: Text(l10n.ganaFormManasCreateNew,
                    style: const TextStyle(color: AppColors.primary)),
                onPressed: () async {
                  final created = await context.pushNamed<bool>(
                      AppRoutes.brahmaManasForm);
                  if (created == true && context.mounted) {
                    context
                        .read<GanaFormBloc>()
                        .add(GanaFormLoadEvent(state.ganaId));
                  }
                },
              ),
            ],
          ),
        const SizedBox(height: 24),
        _FieldLabel(l10n.ganaFormTaskPromptLabel),
        const SizedBox(height: 6),
        TextField(
          controller: taskCtrl,
          decoration: _inputDeco(l10n.ganaFormTaskPromptHint),
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormTaskPromptChangedEvent(v)),
          minLines: 4,
          maxLines: 10,
        ),
        const SizedBox(height: 24),
        _SectionTitle(l10n.ganaFormInputSectionTitle),
        const SizedBox(height: 10),
        _InputSection(state: state, userRefCtrl: userRefCtrl),
        const SizedBox(height: 24),
        _SectionTitle(l10n.ganaFormOutputSectionTitle),
        const SizedBox(height: 10),
        _OutputSection(state: state),
        const SizedBox(height: 24),
        _SectionTitle(l10n.ganaFormModelSectionTitle),
        const SizedBox(height: 10),
        _ModelDropdown(state: state),
        const SizedBox(height: 24),
        _SectionTitle(l10n.ganaFormTriggersSectionTitle),
        const SizedBox(height: 10),
        _TriggersSection(
          state: state,
          intervalCtrl: intervalCtrl,
          maxOutputsCtrl: maxOutputsCtrl,
        ),
        const SizedBox(height: 24),
        _EnabledSwitch(state: state),
        // Save-blocker hint — only shows when canSave is false. Tells the
        // user exactly what's missing so they don't have to guess why the
        // top-right Save button is greyed out.
        if (!state.canSave) ...[
          const SizedBox(height: 24),
          _SaveBlockerHint(reason: state.saveBlocker(l10n) ?? ''),
        ],
        if (state.isEditMode) ...[
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(l10n.ganaFormDeleteAction),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.ganaFormDeleteConfirmTitle),
        content: Text(l10n.ganaFormDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.ganaFormDeleteConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.ganaFormDeleteConfirmConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (context.mounted) {
      context.read<GanaFormBloc>().add(const GanaFormDeleteEvent());
    }
  }
}

// ── Sections ─────────────────────────────────────────────────────────────────

// All three sections share the same shape: a tappable "selector tile"
// that summarises the current pick, and on tap opens a bottom sheet
// with a scrollable list of options. The Material `DropdownButtonFormField`
// looked cramped (12-line popup, no selected-state visuals, no avatars).
// The new sheet pattern matches `manas_membership_sheet.dart` so the
// rest of the app feels consistent.

class _InputSection extends StatelessWidget {
  const _InputSection({required this.state, required this.userRefCtrl});
  final GanaFormState state;
  final TextEditingController userRefCtrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectorTile(
          icon: Icons.input_rounded,
          title: l10n.ganaFormInputSectionTitle,
          subtitle: _inputTypeLabel(l10n, state.inputType),
          onTap: () => _openInputTypeSheet(context, state, l10n),
        ),
        const SizedBox(height: 10),
        if (state.inputType != null)
          _InputRefPicker(state: state, userRefCtrl: userRefCtrl),
      ],
    );
  }
}

class _InputRefPicker extends StatelessWidget {
  const _InputRefPicker({required this.state, required this.userRefCtrl});
  final GanaFormState state;
  final TextEditingController userRefCtrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (state.inputType!) {
      case GanaInputType.channel:
        return _SelectorTile(
          icon: Icons.forum_outlined,
          title: l10n.ganaFormInputChannel,
          subtitle: _channelName(state.channels, state.inputRefId) ??
              l10n.ganaFormInputPickHint,
          empty: state.inputRefId == null,
          onTap: () => _openSheet<String>(
            context: context,
            title: l10n.ganaFormInputChannel,
            current: state.inputRefId,
            options: [
              for (final c in state.channels)
                _PickOption(value: c.channelId, label: c.name),
            ],
            onPicked: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormInputRefChangedEvent(v)),
          ),
        );
      case GanaInputType.privateChannel:
        return _SelectorTile(
          icon: Icons.lock_outline,
          title: l10n.ganaFormInputPrivateChannel,
          subtitle: _privateChannelName(state.privateChannels, state.inputRefId) ??
              l10n.ganaFormInputPickHint,
          empty: state.inputRefId == null,
          onTap: () => _openSheet<String>(
            context: context,
            title: l10n.ganaFormInputPrivateChannel,
            current: state.inputRefId,
            options: [
              for (final c in state.privateChannels)
                _PickOption(value: c.groupId, label: c.name),
            ],
            onPicked: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormInputRefChangedEvent(v)),
          ),
        );
      case GanaInputType.dm:
        return _SelectorTile(
          icon: Icons.alternate_email_rounded,
          title: l10n.ganaFormInputDm,
          subtitle: _dmName(state.dmConversations, state.inputRefId) ??
              l10n.ganaFormInputPickHint,
          empty: state.inputRefId == null,
          onTap: () => _openSheet<String>(
            context: context,
            title: l10n.ganaFormInputDm,
            current: state.inputRefId,
            options: [
              for (final d in state.dmConversations)
                _PickOption(
                  value: d.id.toString(),
                  label: _shortKey(d.otherPubkey),
                ),
            ],
            onPicked: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormInputRefChangedEvent(v)),
          ),
        );
      case GanaInputType.user:
        // Pubkeys aren't a curated list — keep the text field.
        return TextField(
          controller: userRefCtrl,
          decoration: _inputDeco(l10n.ganaFormInputUserHint),
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormInputRefChangedEvent(v.isEmpty ? null : v)),
        );
      case GanaInputType.followedNote:
        return _SelectorTile(
          icon: Icons.bookmark_outline,
          title: l10n.ganaFormInputFollowedNote,
          subtitle: _followedNoteLabel(state.followedNotes, state.inputRefId) ??
              l10n.ganaFormInputPickHint,
          empty: state.inputRefId == null,
          onTap: () => _openSheet<String>(
            context: context,
            title: l10n.ganaFormInputFollowedNote,
            current: state.inputRefId,
            options: [
              for (final f in state.followedNotes)
                _PickOption(
                  value: f.eventId,
                  label: f.contentPreview.isEmpty
                      ? f.eventId.substring(0, 12)
                      : f.contentPreview,
                ),
            ],
            onPicked: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormInputRefChangedEvent(v)),
          ),
        );
    }
  }
}

class _OutputSection extends StatelessWidget {
  const _OutputSection({required this.state});
  final GanaFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectorTile(
          icon: Icons.upload_rounded,
          title: l10n.ganaFormOutputSectionTitle,
          subtitle: _outputTypeLabel(l10n, state.outputType),
          onTap: () => _openOutputTypeSheet(context, state, l10n),
        ),
        const SizedBox(height: 10),
        if (state.outputType != GanaOutputType.feed)
          _OutputRefPicker(state: state),
      ],
    );
  }
}

class _OutputRefPicker extends StatelessWidget {
  const _OutputRefPicker({required this.state});
  final GanaFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (state.outputType) {
      case GanaOutputType.feed:
        return const SizedBox.shrink();
      case GanaOutputType.channel:
        return _SelectorTile(
          icon: Icons.forum_outlined,
          title: l10n.ganaFormOutputChannel,
          subtitle: _channelName(state.channels, state.outputChannelId) ??
              l10n.ganaFormOutputPickHint,
          empty: state.outputChannelId == null,
          onTap: () => _openSheet<String>(
            context: context,
            title: l10n.ganaFormOutputChannel,
            current: state.outputChannelId,
            options: [
              for (final c in state.channels)
                _PickOption(value: c.channelId, label: c.name),
            ],
            onPicked: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormOutputRefChangedEvent(v)),
          ),
        );
      case GanaOutputType.privateChannel:
        return _SelectorTile(
          icon: Icons.lock_outline,
          title: l10n.ganaFormOutputPrivateChannel,
          subtitle: _privateChannelName(state.privateChannels, state.outputGroupId) ??
              l10n.ganaFormOutputPickHint,
          empty: state.outputGroupId == null,
          onTap: () => _openSheet<String>(
            context: context,
            title: l10n.ganaFormOutputPrivateChannel,
            current: state.outputGroupId,
            options: [
              for (final c in state.privateChannels)
                _PickOption(value: c.groupId, label: c.name),
            ],
            onPicked: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormOutputRefChangedEvent(v)),
          ),
        );
      case GanaOutputType.dm:
        return _SelectorTile(
          icon: Icons.alternate_email_rounded,
          title: l10n.ganaFormOutputDm,
          subtitle: _dmName(
                state.dmConversations,
                state.outputDmConversationId?.toString(),
              ) ??
              l10n.ganaFormOutputPickHint,
          empty: state.outputDmConversationId == null,
          onTap: () => _openSheet<int>(
            context: context,
            title: l10n.ganaFormOutputDm,
            current: state.outputDmConversationId,
            options: [
              for (final d in state.dmConversations)
                _PickOption(value: d.id, label: _shortKey(d.otherPubkey)),
            ],
            onPicked: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormOutputRefChangedEvent(v)),
          ),
        );
    }
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({required this.state});
  final GanaFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SelectorTile(
      icon: Icons.psychology_alt_outlined,
      title: l10n.ganaFormModelSectionTitle,
      subtitle: state.desiredModelId ?? l10n.ganaFormModelUseActive,
      onTap: () => _openSheet<String?>(
        context: context,
        title: l10n.ganaFormModelSectionTitle,
        current: state.desiredModelId,
        nullableOption: _PickOption(
          value: null,
          label: l10n.ganaFormModelUseActive,
        ),
        options: [
          for (final m in state.availableModels)
            _PickOption(value: m, label: m),
        ],
        onPicked: (v) =>
            context.read<GanaFormBloc>().add(GanaFormModelChangedEvent(v)),
      ),
    );
  }
}

// ── Sheet plumbing ───────────────────────────────────────────────────────────

