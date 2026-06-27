part of '../pages/gana_form_page.dart';

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
      _PickOption(value: GanaInputType.group, label: l10n.ganaFormInputGroup),
      _PickOption(
          value: GanaInputType.privateGroup,
          label: l10n.ganaFormInputPrivateGroup),
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
          value: GanaOutputType.group, label: l10n.ganaFormOutputGroup),
      _PickOption(
          value: GanaOutputType.privateGroup,
          label: l10n.ganaFormOutputPrivateGroup),
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
    case GanaInputType.group:
      return l10n.ganaFormInputGroup;
    case GanaInputType.privateGroup:
      return l10n.ganaFormInputPrivateGroup;
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
    case GanaOutputType.group:
      return l10n.ganaFormOutputGroup;
    case GanaOutputType.privateGroup:
      return l10n.ganaFormOutputPrivateGroup;
    case GanaOutputType.dm:
      return l10n.ganaFormOutputDm;
  }
}

String? _groupName(List<GroupEntity> all, String? id) {
  if (id == null) return null;
  for (final c in all) {
    if (c.groupId == id) return c.name;
  }
  return id.substring(0, id.length < 12 ? id.length : 12);
}

String? _privateGroupName(
    List<PrivateGroupEntity> all, String? id) {
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
    final presets = GanaTriggerPreset.validFor(state.inputType);
    final selected = state.triggerPreset;
    final needsInterval = selected == GanaTriggerPreset.onSchedule ||
        selected == GanaTriggerPreset.messageOrSchedule;
    final isRecurring = state.triggerMode == GanaTriggerMode.recurring;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ganaFormTriggerQuestion,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final p in presets)
          RadioListTile<GanaTriggerPreset>(
            value: p,
            groupValue: selected,
            onChanged: (v) {
              if (v == null) return;
              context
                  .read<GanaFormBloc>()
                  .add(GanaFormTriggerPresetChangedEvent(v));
            },
            title: Text(_presetLabel(l10n, p)),
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        if (needsInterval) ...[
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
        if (isRecurring) ...[
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

  String _presetLabel(AppLocalizations l10n, GanaTriggerPreset p) {
    switch (p) {
      case GanaTriggerPreset.onceOnEnable:
        return l10n.ganaFormPresetOnceOnEnable;
      case GanaTriggerPreset.onceOnFirstMessage:
        return l10n.ganaFormPresetOnceOnFirstMessage;
      case GanaTriggerPreset.everyMessage:
        return l10n.ganaFormPresetEveryMessage;
      case GanaTriggerPreset.onSchedule:
        return l10n.ganaFormPresetOnSchedule;
      case GanaTriggerPreset.messageOrSchedule:
        return l10n.ganaFormPresetMessageOrSchedule;
    }
  }
}

