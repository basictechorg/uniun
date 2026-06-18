import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/theme/app_theme.dart';
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
  bool _seeded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _taskCtrl.dispose();
    _userRefCtrl.dispose();
    _intervalCtrl.dispose();
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
  });

  final GanaFormState state;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController taskCtrl;
  final TextEditingController userRefCtrl;
  final TextEditingController intervalCtrl;

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
          _Empty(l10n.ganaFormManasEmpty)
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
        _TriggersSection(state: state, intervalCtrl: intervalCtrl),
        const SizedBox(height: 24),
        _EnabledSwitch(state: state),
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
        DropdownButtonFormField<GanaInputType?>(
          initialValue: state.inputType,
          decoration: _inputDeco(l10n.ganaFormInputPickHint),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(l10n.ganaFormInputStandalone),
            ),
            DropdownMenuItem(
              value: GanaInputType.channel,
              child: Text(l10n.ganaFormInputChannel),
            ),
            DropdownMenuItem(
              value: GanaInputType.privateChannel,
              child: Text(l10n.ganaFormInputPrivateChannel),
            ),
            DropdownMenuItem(
              value: GanaInputType.dm,
              child: Text(l10n.ganaFormInputDm),
            ),
            DropdownMenuItem(
              value: GanaInputType.user,
              child: Text(l10n.ganaFormInputUser),
            ),
            DropdownMenuItem(
              value: GanaInputType.followedNote,
              child: Text(l10n.ganaFormInputFollowedNote),
            ),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormInputTypeChangedEvent(v)),
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
        return DropdownButtonFormField<String>(
          initialValue: state.inputRefId,
          decoration: _inputDeco(l10n.ganaFormInputPickHint),
          items: [
            for (final c in state.channels)
              DropdownMenuItem(value: c.channelId, child: Text(c.name)),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormInputRefChangedEvent(v)),
        );
      case GanaInputType.privateChannel:
        return DropdownButtonFormField<String>(
          initialValue: state.inputRefId,
          decoration: _inputDeco(l10n.ganaFormInputPickHint),
          items: [
            for (final c in state.privateChannels)
              DropdownMenuItem(value: c.groupId, child: Text(c.name)),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormInputRefChangedEvent(v)),
        );
      case GanaInputType.dm:
        return DropdownButtonFormField<String>(
          initialValue: state.inputRefId,
          decoration: _inputDeco(l10n.ganaFormInputPickHint),
          items: [
            for (final d in state.dmConversations)
              DropdownMenuItem(
                value: d.id.toString(),
                child: Text(_shortKey(d.otherPubkey)),
              ),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormInputRefChangedEvent(v)),
        );
      case GanaInputType.user:
        return TextField(
          controller: userRefCtrl,
          decoration: _inputDeco(l10n.ganaFormInputUserHint),
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormInputRefChangedEvent(v.isEmpty ? null : v)),
        );
      case GanaInputType.followedNote:
        return DropdownButtonFormField<String>(
          initialValue: state.inputRefId,
          decoration: _inputDeco(l10n.ganaFormInputPickHint),
          items: [
            for (final f in state.followedNotes)
              DropdownMenuItem(
                value: f.eventId,
                child: Text(
                  f.contentPreview.isEmpty
                      ? f.eventId.substring(0, 12)
                      : f.contentPreview,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormInputRefChangedEvent(v)),
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
        DropdownButtonFormField<GanaOutputType>(
          initialValue: state.outputType,
          decoration: _inputDeco(l10n.ganaFormOutputPickHint),
          items: [
            DropdownMenuItem(
              value: GanaOutputType.feed,
              child: Text(l10n.ganaFormOutputFeed),
            ),
            DropdownMenuItem(
              value: GanaOutputType.channel,
              child: Text(l10n.ganaFormOutputChannel),
            ),
            DropdownMenuItem(
              value: GanaOutputType.privateChannel,
              child: Text(l10n.ganaFormOutputPrivateChannel),
            ),
            DropdownMenuItem(
              value: GanaOutputType.dm,
              child: Text(l10n.ganaFormOutputDm),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            context.read<GanaFormBloc>().add(GanaFormOutputTypeChangedEvent(v));
          },
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
        return DropdownButtonFormField<String>(
          initialValue: state.outputChannelId,
          decoration: _inputDeco(l10n.ganaFormOutputPickHint),
          items: [
            for (final c in state.channels)
              DropdownMenuItem(value: c.channelId, child: Text(c.name)),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormOutputRefChangedEvent(v)),
        );
      case GanaOutputType.privateChannel:
        return DropdownButtonFormField<String>(
          initialValue: state.outputGroupId,
          decoration: _inputDeco(l10n.ganaFormOutputPickHint),
          items: [
            for (final c in state.privateChannels)
              DropdownMenuItem(value: c.groupId, child: Text(c.name)),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormOutputRefChangedEvent(v)),
        );
      case GanaOutputType.dm:
        return DropdownButtonFormField<int>(
          initialValue: state.outputDmConversationId,
          decoration: _inputDeco(l10n.ganaFormOutputPickHint),
          items: [
            for (final d in state.dmConversations)
              DropdownMenuItem(
                value: d.id,
                child: Text(_shortKey(d.otherPubkey)),
              ),
          ],
          onChanged: (v) => context
              .read<GanaFormBloc>()
              .add(GanaFormOutputRefChangedEvent(v)),
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
    return DropdownButtonFormField<String?>(
      initialValue: state.desiredModelId,
      decoration: _inputDeco(l10n.ganaFormModelUseActive),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.ganaFormModelUseActive)),
        for (final m in state.availableModels)
          DropdownMenuItem(value: m, child: Text(m)),
      ],
      onChanged: (v) =>
          context.read<GanaFormBloc>().add(GanaFormModelChangedEvent(v)),
    );
  }
}

class _TriggersSection extends StatelessWidget {
  const _TriggersSection({required this.state, required this.intervalCtrl});
  final GanaFormState state;
  final TextEditingController intervalCtrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reactiveEnabled = state.inputType != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: state.triggerReactive,
          onChanged: reactiveEnabled
              ? (v) => context
                  .read<GanaFormBloc>()
                  .add(GanaFormReactiveToggleEvent(v))
              : null,
          title: Text(l10n.ganaFormReactiveLabel),
          subtitle: Text(l10n.ganaFormReactiveHelp),
          contentPadding: EdgeInsets.zero,
        ),
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

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
      );
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
