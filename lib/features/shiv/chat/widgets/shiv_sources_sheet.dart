import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/widgets/note_card/embedded_note_card.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_sources_cubit.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Bottom sheet listing the source notes that seeded the RAG context for the
/// last Shiv reply. Read-only — each note renders with [EmbeddedNoteCard].
/// The ids are ephemeral (current turn only); resolution is done on open.
class ShivSourcesSheet extends StatelessWidget {
  const ShivSourcesSheet({super.key, required this.noteIds});

  final List<String> noteIds;

  static Future<void> show(BuildContext context, List<String> noteIds) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ShivSourcesSheet(noteIds: noteIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShivSourcesCubit()..load(noteIds),
      child: const _ShivSourcesView(),
    );
  }
}

class _ShivSourcesView extends StatelessWidget {
  const _ShivSourcesView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
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
              l10n.shivSourcesSheetTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<ShivSourcesCubit, ShivSourcesState>(
                builder: (context, state) {
                  if (state.status == ShivSourcesStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.notes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          l10n.shivSourcesEmpty,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: state.notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => EmbeddedNoteCard(note: state.notes[i]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
