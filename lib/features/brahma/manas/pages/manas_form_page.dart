import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/brahma/manas/bloc/manas_form_bloc.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/features/brahma/manas/widgets/manas_icon_picker.dart';
import 'package:uniun/l10n/app_localizations.dart';

class ManasFormPage extends StatelessWidget {
  const ManasFormPage({super.key, this.manasId});

  /// Null = create mode. Non-null = edit existing Manas.
  final String? manasId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<ManasFormBloc>()..add(ManasFormLoadEvent(manasId)),
      child: const _ManasFormView(),
    );
  }
}

class _ManasFormView extends StatefulWidget {
  const _ManasFormView();

  @override
  State<_ManasFormView> createState() => _ManasFormViewState();
}

class _ManasFormViewState extends State<_ManasFormView> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();

  bool _seeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<ManasFormBloc, ManasFormState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ManasFormStatus.saved ||
            state.status == ManasFormStatus.deleted) {
          Navigator.of(context).pop(true);
        }
        if (state.status == ManasFormStatus.ready && !_seeded) {
          _seeded = true;
          _nameController.text = state.name;
          _descController.text = state.description;
        }
        if (state.status == ManasFormStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final loading = state.status == ManasFormStatus.loading ||
            state.status == ManasFormStatus.initial;
        final isEdit = state.isEditMode;

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            scrolledUnderElevation: 0,
            leading: UniunBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              isEdit
                  ? (state.name.isEmpty
                      ? l10n.manasFormEditTitleFallback
                      : l10n.manasFormEditTitle(state.name))
                  : l10n.manasFormCreateTitle,
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
                        .read<ManasFormBloc>()
                        .add(const ManasFormSubmitEvent())
                    : null,
                child: Text(
                  l10n.manasFormSaveAction,
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
                  child: DropLoadingIndicator(color: AppColors.primary),
                )
              : _Body(
                  state: state,
                  nameController: _nameController,
                  descController: _descController,
                  searchController: _searchController,
                ),
        );
      },
    );
  }

}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.nameController,
    required this.descController,
    required this.searchController,
  });

  final ManasFormState state;
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = state.isEditMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Icon picker tile — auto-suggested from the name, tappable to
            // override. Stays in sync with the bloc's iconName via context.watch.
            _IconPickerTile(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(l10n.manasFormNameLabel),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: _inputDeco(l10n.manasFormNameHint),
                    onChanged: (v) => context
                        .read<ManasFormBloc>()
                        .add(ManasFormNameChangedEvent(v)),
                    maxLength: 60,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldLabel(l10n.manasFormDescriptionLabel),
        const SizedBox(height: 6),
        TextField(
          controller: descController,
          decoration: _inputDeco(l10n.manasFormDescriptionHint),
          onChanged: (v) => context
              .read<ManasFormBloc>()
              .add(ManasFormDescriptionChangedEvent(v)),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          l10n.manasFormMembershipSectionTitle(state.pendingMembership.length),
        ),
        const SizedBox(height: 10),
        if (state.pendingMembership.isEmpty)
          _SubtleHint(l10n.manasFormMembershipEmpty)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in state.pendingMembership)
                _MembershipChip(
                  id: id,
                  preview: state.membershipPreviews[id],
                ),
            ],
          ),
        const SizedBox(height: 24),
        _SectionTitle(l10n.manasFormAddNotesSectionTitle),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          decoration: _inputDeco(l10n.manasFormSearchHint).copyWith(
            prefixIcon: const Icon(Icons.search_rounded,
                size: 20, color: AppColors.onSurfaceVariant),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      searchController.clear();
                      context
                          .read<ManasFormBloc>()
                          .add(const ManasFormSearchEvent(''));
                    },
                  ),
          ),
          onChanged: (v) => context
              .read<ManasFormBloc>()
              .add(ManasFormSearchEvent(v)),
        ),
        const SizedBox(height: 12),
        if (state.searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: DropLoadingIndicator(
                    size: 20, color: AppColors.primary),
              ),
            ),
          )
        else if (state.searchQuery.isNotEmpty && state.searchResults.isEmpty)
          _SubtleHint(l10n.manasFormSearchEmpty)
        else
          ...[
            for (final r in state.searchResults)
              _SearchResultRow(
                preview: r,
                included: state.pendingMembership.contains(r.noteId),
                onTap: () => context
                    .read<ManasFormBloc>()
                    .add(ManasFormToggleMembershipEvent(r)),
              ),
          ],
        if (isEdit) ...[
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                color: AppColors.error.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(l10n.manasFormDeleteAction),
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
        title: Text(l10n.manasFormDeleteConfirmTitle),
        content: Text(l10n.manasFormDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.manasFormDeleteConfirmCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l10n.manasFormDeleteConfirmConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    context.read<ManasFormBloc>().add(const ManasFormDeleteEvent());
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.outlineVariant),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      counterText: '',
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
      ),
    );
  }
}

class _IconPickerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iconName =
        context.select<ManasFormBloc, String?>((b) => b.state.iconName);
    return GestureDetector(
      onTap: () async {
        final picked = await ManasIconPicker.show(context, current: iconName);
        if (picked != null && context.mounted) {
          context.read<ManasFormBloc>().add(ManasFormIconPickedEvent(picked));
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Icon(
          ManasIcons.byName(iconName),
          color: AppColors.primary,
          size: 26,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.outline,
          letterSpacing: 0.8,
        ),
      );
}

class _SubtleHint extends StatelessWidget {
  const _SubtleHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.outlineVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
}

class _MembershipChip extends StatelessWidget {
  const _MembershipChip({required this.id, required this.preview});
  final String id;
  final ManasNotePreview? preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = preview?.preview.isNotEmpty == true
        ? preview!.preview
        : l10n.manasFormNoteUnavailable;
    return InputChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
      avatar: const Icon(
        Icons.bookmark_rounded,
        size: 16,
        color: AppColors.primary,
      ),
      onDeleted: () => context.read<ManasFormBloc>().add(
            ManasFormToggleMembershipEvent(
              preview ??
                  ManasNotePreview(
                    noteId: id,
                    preview: '',
                    kind: ManasNoteKind.unknown,
                  ),
            ),
          ),
      backgroundColor: AppColors.surfaceContainerLow,
      side: BorderSide(
        color: AppColors.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.preview,
    required this.included,
    required this.onTap,
  });

  final ManasNotePreview preview;
  final bool included;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(
              included
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              size: 20,
              color: included ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                preview.preview,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (preview.kind != ManasNoteKind.unknown) ...[
              const SizedBox(width: 8),
              _KindBadge(kind: preview.kind, l10n: l10n),
            ],
          ],
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.l10n});
  final ManasNoteKind kind;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (kind) {
      ManasNoteKind.saved => (l10n.manasFormKindSaved, AppColors.graphSaved),
      ManasNoteKind.own   => (l10n.manasFormKindOwn,   AppColors.graphOwn),
      ManasNoteKind.draft => (l10n.manasFormKindDraft, AppColors.graphDraft),
      ManasNoteKind.unknown => ('', AppColors.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
