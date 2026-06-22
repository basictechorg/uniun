import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/followed_note/followed_note_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/features/shiv/gana/form/bloc/gana_form_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

class GanaFormPage extends StatelessWidget {
  const GanaFormPage({super.key, this.ganaId});
  final String? ganaId; // null ⇒ create mode

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<GanaFormBloc>()..add(GanaFormLoadEvent(ganaId)),
      child: const _GanaFormView(),
    );
  }
}

class _GanaFormView extends StatefulWidget {
  const _GanaFormView();
  @override
  State<_GanaFormView> createState() => _GanaFormViewState();
}

class _GanaFormViewState extends State<_GanaFormView> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _taskCtrl = TextEditingController();
  final _userRefCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController();
  final _maxOutputsCtrl = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _taskCtrl.dispose();
    _userRefCtrl.dispose();
    _intervalCtrl.dispose();
    _maxOutputsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<GanaFormBloc, GanaFormState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == GanaFormStatus.saved ||
            state.status == GanaFormStatus.deleted) {
          Navigator.of(context).pop(true);
        }
        if (state.status == GanaFormStatus.ready && !_seeded) {
          _seeded = true;
          _nameCtrl.text = state.name;
          _descCtrl.text = state.description;
          _taskCtrl.text = state.taskPrompt;
          _userRefCtrl.text = state.inputType == GanaInputType.user
              ? (state.inputRefId ?? '')
              : '';
          _intervalCtrl.text =
              state.triggerIntervalMinutes?.toString() ?? '';
          _maxOutputsCtrl.text = state.maxOutputs?.toString() ?? '';
        }
        if (state.status == GanaFormStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        final loading = state.status == GanaFormStatus.loading ||
            state.status == GanaFormStatus.initial;
        final isEdit = state.isEditMode;

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            scrolledUnderElevation: 0,
            leading:
                UniunBackButton(onPressed: () => Navigator.of(context).pop()),
            title: Text(
              isEdit
                  ? (state.name.isEmpty
                      ? l10n.ganaFormEditTitleFallback
                      : l10n.ganaFormEditTitle(state.name))
                  : l10n.ganaFormCreateTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: state.canSave
                    ? () => context
                        .read<GanaFormBloc>()
                        .add(const GanaFormSubmitEvent())
                    : null,
                child: Text(
                  l10n.ganaFormSaveAction,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: state.canSave
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          body: loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
              : _Body(
                  state: state,
                  nameCtrl: _nameCtrl,
                  descCtrl: _descCtrl,
                  taskCtrl: _taskCtrl,
                  userRefCtrl: _userRefCtrl,
                  intervalCtrl: _intervalCtrl,
                  maxOutputsCtrl: _maxOutputsCtrl,
                ),
        );
      },
    );
  }
}

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

class _PickOption<T> {
  const _PickOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Generic option picker. `nullableOption` lets the caller offer "none /
/// default" as the first row (used by the model picker for "Use active").
Future<void> _openSheet<T>({
  required BuildContext context,
  required String title,
  required T? current,
  required List<_PickOption<T>> options,
  required ValueChanged<T?> onPicked,
  _PickOption<T?>? nullableOption,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetCtx) {
      final rows = <Widget>[];
      if (nullableOption != null) {
        rows.add(_SheetRow(
          label: nullableOption.label,
          active: current == null,
          onTap: () {
            onPicked(null);
            Navigator.of(sheetCtx).pop();
          },
        ));
      }
      if (options.isEmpty && nullableOption == null) {
        rows.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            '—',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ));
      }
      for (final o in options) {
        rows.add(_SheetRow(
          label: o.label,
          active: current != null && current == o.value,
          onTap: () {
            onPicked(o.value);
            Navigator.of(sheetCtx).pop();
          },
        ));
      }
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: ListView(shrinkWrap: true, children: rows)),
            ],
          ),
        ),
      );
    },
  );
}

void _openInputTypeSheet(
  BuildContext context,
  GanaFormState state,
  AppLocalizations l10n,
) {
  _openSheet<GanaInputType?>(
    context: context,
    title: l10n.ganaFormInputSectionTitle,
    current: state.inputType,
    nullableOption: _PickOption(
      value: null,
      label: l10n.ganaFormInputStandalone,
    ),
    options: [
      _PickOption(value: GanaInputType.channel, label: l10n.ganaFormInputChannel),
      _PickOption(
          value: GanaInputType.privateChannel,
          label: l10n.ganaFormInputPrivateChannel),
      _PickOption(value: GanaInputType.dm, label: l10n.ganaFormInputDm),
      _PickOption(value: GanaInputType.user, label: l10n.ganaFormInputUser),
      _PickOption(
          value: GanaInputType.followedNote,
          label: l10n.ganaFormInputFollowedNote),
    ],
    onPicked: (v) =>
        context.read<GanaFormBloc>().add(GanaFormInputTypeChangedEvent(v)),
  );
}

void _openOutputTypeSheet(
  BuildContext context,
  GanaFormState state,
  AppLocalizations l10n,
) {
  _openSheet<GanaOutputType>(
    context: context,
    title: l10n.ganaFormOutputSectionTitle,
    current: state.outputType,
    options: [
      _PickOption(value: GanaOutputType.feed, label: l10n.ganaFormOutputFeed),
      _PickOption(
          value: GanaOutputType.channel, label: l10n.ganaFormOutputChannel),
      _PickOption(
          value: GanaOutputType.privateChannel,
          label: l10n.ganaFormOutputPrivateChannel),
      _PickOption(value: GanaOutputType.dm, label: l10n.ganaFormOutputDm),
    ],
    onPicked: (v) {
      if (v == null) return;
      context.read<GanaFormBloc>().add(GanaFormOutputTypeChangedEvent(v));
    },
  );
}

class _SelectorTile extends StatelessWidget {
  const _SelectorTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.empty = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: empty
                ? AppColors.outlineVariant.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: empty
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active)
              const Icon(Icons.check_rounded,
                  size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── Label helpers ───────────────────────────────────────────────────────────

String _inputTypeLabel(AppLocalizations l10n, GanaInputType? type) {
  if (type == null) return l10n.ganaFormInputStandalone;
  switch (type) {
    case GanaInputType.channel:
      return l10n.ganaFormInputChannel;
    case GanaInputType.privateChannel:
      return l10n.ganaFormInputPrivateChannel;
    case GanaInputType.dm:
      return l10n.ganaFormInputDm;
    case GanaInputType.user:
      return l10n.ganaFormInputUser;
    case GanaInputType.followedNote:
      return l10n.ganaFormInputFollowedNote;
  }
}

String _outputTypeLabel(AppLocalizations l10n, GanaOutputType type) {
  switch (type) {
    case GanaOutputType.feed:
      return l10n.ganaFormOutputFeed;
    case GanaOutputType.channel:
      return l10n.ganaFormOutputChannel;
    case GanaOutputType.privateChannel:
      return l10n.ganaFormOutputPrivateChannel;
    case GanaOutputType.dm:
      return l10n.ganaFormOutputDm;
  }
}

String? _channelName(List<ChannelEntity> all, String? id) {
  if (id == null) return null;
  for (final c in all) {
    if (c.channelId == id) return c.name;
  }
  return id.substring(0, id.length < 12 ? id.length : 12);
}

String? _privateChannelName(
    List<PrivateChannelEntity> all, String? id) {
  if (id == null) return null;
  for (final c in all) {
    if (c.groupId == id) return c.name;
  }
  return id;
}

String? _dmName(List<DmConversationEntity> all, String? id) {
  if (id == null) return null;
  final parsed = int.tryParse(id);
  if (parsed == null) return null;
  for (final d in all) {
    if (d.id == parsed) return _shortKey(d.otherPubkey);
  }
  return null;
}

String? _followedNoteLabel(List<FollowedNoteEntity> all, String? id) {
  if (id == null) return null;
  for (final f in all) {
    if (f.eventId == id) {
      return f.contentPreview.isEmpty
          ? f.eventId.substring(0, 12)
          : f.contentPreview;
    }
  }
  return null;
}

class _TriggersSection extends StatelessWidget {
  const _TriggersSection({
    required this.state,
    required this.intervalCtrl,
    required this.maxOutputsCtrl,
  });
  final GanaFormState state;
  final TextEditingController intervalCtrl;
  final TextEditingController maxOutputsCtrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasInput = state.inputType != null;
    final oneShot = state.triggerMode == GanaTriggerMode.oneShot;

    // Per-mode UI:
    //   one-shot + standalone : no triggers — fires on enable
    //   one-shot + input      : reactive only (required)
    //   recurring + standalone: interval only (required)
    //   recurring + input     : reactive + interval (either)
    final showReactive = hasInput; // reactive is meaningless without input
    final showInterval = !oneShot; // one-shot has no notion of "every Nm"

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Run mode — recurring (cron) vs one-shot (fire once, auto-disable).
        _ModeSegmented(
          mode: state.triggerMode,
          onChanged: (m) => context
              .read<GanaFormBloc>()
              .add(GanaFormTriggerModeChangedEvent(m)),
        ),
        const SizedBox(height: 4),
        Text(
          oneShot
              ? l10n.ganaFormModeOneShotHelp
              : l10n.ganaFormModeRecurringHelp,
          style: const TextStyle(
              fontSize: 12, color: AppColors.onSurfaceVariant),
        ),
        // Standalone + one-shot has no trigger UI: it fires once when the
        // user flips `enabled` on. Show a single explanatory note instead.
        if (oneShot && !hasInput) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.ganaFormOneShotStandaloneNote,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showReactive) ...[
          const SizedBox(height: 16),
          SwitchListTile(
            value: state.triggerReactive,
            onChanged: (v) => context
                .read<GanaFormBloc>()
                .add(GanaFormReactiveToggleEvent(v)),
            title: Text(l10n.ganaFormReactiveLabel),
            subtitle: Text(
              oneShot
                  ? l10n.ganaFormReactiveRequiredNote
                  : l10n.ganaFormReactiveHelp,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
        if (showInterval) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(l10n.ganaFormIntervalLabel)),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: intervalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('5'),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    context
                        .read<GanaFormBloc>()
                        .add(GanaFormIntervalChangedEvent(n));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.ganaFormIntervalUnit,
            style: const TextStyle(
                fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          // Recurring-only safety cap. Without this the Gana could keep
          // publishing forever if the user forgets about it.
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(l10n.ganaFormMaxOutputsLabel)),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: maxOutputsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('10'),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    context
                        .read<GanaFormBloc>()
                        .add(GanaFormMaxOutputsChangedEvent(n));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.ganaFormMaxOutputsHelp,
            style: const TextStyle(
                fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _EnabledSwitch extends StatelessWidget {
  const _EnabledSwitch({required this.state});
  final GanaFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile(
      value: state.enabled,
      onChanged: (v) =>
          context.read<GanaFormBloc>().add(GanaFormEnabledToggleEvent(v)),
      title: Text(l10n.ganaFormEnabledLabel),
      subtitle: Text(l10n.ganaFormEnabledHelp),
      contentPadding: EdgeInsets.zero,
    );
  }
}

// ── Atoms ────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      );
}

class _SectionSubtitle extends StatelessWidget {
  const _SectionSubtitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, color: AppColors.onSurfaceVariant),
      );
}

/// Inline hint that explains why `canSave` is false. Replaces the
/// previous silent-grey-Save UX where the user had to guess what was
/// missing. Pulls its message from `state.saveBlocker(l10n)`.
class _SaveBlockerHint extends StatelessWidget {
  const _SaveBlockerHint({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    if (reason.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recurring vs one-shot segmented selector.
class _ModeSegmented extends StatelessWidget {
  const _ModeSegmented({required this.mode, required this.onChanged});
  final GanaTriggerMode mode;
  final ValueChanged<GanaTriggerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _modePill(
            label: l10n.ganaFormModeRecurring,
            active: mode == GanaTriggerMode.recurring,
            onTap: () => onChanged(GanaTriggerMode.recurring),
          ),
          _modePill(
            label: l10n.ganaFormModeOneShot,
            active: mode == GanaTriggerMode.oneShot,
            onTap: () => onChanged(GanaTriggerMode.oneShot),
          ),
        ],
      ),
    );
  }

  Widget _modePill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty-state for the Manas section when the user has zero Manases.
/// Pushes to the Brahma Manas form and reloads on return so the user
/// can keep creating the Gana without losing what they typed.
class _NoManasesCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.ganaFormManasEmpty,
            style: const TextStyle(
                fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              final created =
                  await context.pushNamed<bool>(AppRoutes.brahmaManasForm);
              if (created == true && context.mounted) {
                final bloc = context.read<GanaFormBloc>();
                bloc.add(GanaFormLoadEvent(bloc.state.ganaId));
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.ganaFormManasCreateNew),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceContainer,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );

String _shortKey(String s) {
  if (s.length <= 14) return s;
  return '${s.substring(0, 8)}…${s.substring(s.length - 4)}';
}
