import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/note_thread_navigator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/features/followed_notes/cubit/followed_notes_cubit.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/saved_notes/cubit/saved_notes_cubit.dart';
import 'package:uniun/features/saved_notes/cubit/saved_notes_state.dart';
import 'package:uniun/features/thread/pages/thread_page.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';

class SavedNotesPage extends StatelessWidget {
  const SavedNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SavedNotesCubit()..load()),
        BlocProvider(create: (_) => getIt<FollowedNotesCubit>()..load()),
      ],
      child: const _SavedNotesView(),
    );
  }
}

// ── View ───────────────────────────────────────────────────────────────────────

class _SavedNotesView extends StatefulWidget {
  const _SavedNotesView();

  @override
  State<_SavedNotesView> createState() => _SavedNotesViewState();
}

class _SavedNotesViewState extends State<_SavedNotesView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SavedNoteEntity> _filter(List<SavedNoteEntity> notes) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return notes;
    return notes.where((n) {
      return n.content.toLowerCase().contains(q) ||
          n.tTags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.savedNotesTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        elevation: 0,
      ),
      body: KeyboardDismissOnTap(
        child: BlocBuilder<SavedNotesCubit, SavedNotesState>(
        builder: (context, state) {
          if (state.status == SavedNotesStatus.initial ||
              state.status == SavedNotesStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            );
          }
          if (state.status == SavedNotesStatus.error) {
            return Center(
              child: Text(
                state.errorMessage ?? 'Failed to load saved notes',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final filtered = _filter(state.notes);

          return Column(
            children: [
              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.savedNotesSearch,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.onSurfaceVariant,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ── List ────────────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => context.read<SavedNotesCubit>().load(),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: state.notes.isEmpty
                                  ? const _EmptyState()
                                  : const _NoResultsState(),
                            ),
                          ],
                        )
                      : BlocBuilder<FollowedNotesCubit, FollowedNotesState>(
                          builder: (ctx, followedState) {
                            final followedIds = followedState.notes
                                .map((n) => n.eventId)
                                .toSet();
                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox.shrink(),
                              itemBuilder: (ctx, i) {
                                final cubit = context.read<SavedNotesCubit>();
                                final note = filtered[i];
                                final savedEventIds = state.notes
                                    .map((n) => n.eventId)
                                    .toSet();
                                final isFollowed =
                                    followedIds.contains(note.eventId);
                                return NoteCard(
                                  note: note.toNoteEntity(
                                    savedEventIds: savedEventIds,
                                    sourceLabel: state.sourceLabels[note.eventId],
                                  ),
                                  profile: state.profiles[note.authorPubkey],
                                  replyCount: note.cachedReplyCount,
                                  isSaved: true,
                                  isFollowed: isFollowed,
                                  onFollowTap: () {
                                    final followCubit =
                                        ctx.read<FollowedNotesCubit>();
                                    if (isFollowed) {
                                      followCubit.unfollowNote(note.eventId);
                                    } else {
                                      followCubit.followNote(
                                        note.eventId,
                                        note.content.length > 80
                                            ? note.content.substring(0, 80)
                                            : note.content,
                                      );
                                    }
                                  },
                                  onTap: () async {
                                    await openEventThread(
                                      ctx,
                                      note.eventId,
                                      openAsNote: () => Navigator.push(
                                        ctx,
                                        MaterialPageRoute(
                                          builder: (_) => ThreadPage(
                                            noteId: note.eventId,
                                            savedOnly: true,
                                          ),
                                        ),
                                      ),
                                    );
                                    cubit.load();
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_border_rounded,
              size: 56,
              color: AppColors.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.savedNotesEmpty,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.savedNotesEmptySub,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No notes match your search.',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

