import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/note_card/large_note_card.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/thread/widgets/thread_empty_states.dart';
import 'package:uniun/features/thread/widgets/thread_parent_context.dart';

/// Shared thread layout used by the feed, channel, private-channel and DM
/// thread views. Pure UI: parent context → mentioned refs → root card →
/// replies list (each opening its own nested thread).
///
/// Requires a `FollowedNotesCubit` in the widget tree — [LargeNoteCard] watches
/// it for the root note's follow state.
class ThreadConversationBody extends StatelessWidget {
  const ThreadConversationBody({
    super.key,
    required this.root,
    required this.profiles,
    required this.replies,
    required this.onOpenThread,
    this.parentNotes = const [],
    this.mentionedNotes = const [],
    this.replyCount,
  });

  final NoteEntity root;
  final Map<String, ProfileEntity> profiles;
  final List<NoteEntity> parentNotes;
  final List<NoteEntity> mentionedNotes;
  final List<NoteEntity> replies;

  /// Reply count shown on the root card. Defaults to [replies] length.
  final int? replyCount;

  final void Function(String noteId) onOpenThread;

  @override
  Widget build(BuildContext context) {
    final hasTopContext = parentNotes.isNotEmpty || mentionedNotes.isNotEmpty;

    return CustomScrollView(
      slivers: [
        // ── Immediate NIP-10 parent (1 level only) ────────────────────────────
        if (parentNotes.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
            sliver: SliverToBoxAdapter(
              child: ThreadParentContext(
                notes: parentNotes,
                profiles: profiles,
                onNoteTap: onOpenThread,
              ),
            ),
          ),

        // ── Outgoing references — rendered as sibling "parents" above the root.
        if (mentionedNotes.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(
                top: parentNotes.isEmpty ? 16 : 0, left: 20, right: 20),
            sliver: SliverToBoxAdapter(
              child: ThreadParentContext(
                notes: mentionedNotes,
                profiles: profiles,
                isSiblingGroup: true,
                onNoteTap: onOpenThread,
              ),
            ),
          ),

        // ── Focused / root note card ───────────────────────────────────────────
        SliverPadding(
          padding: EdgeInsets.only(
            top: hasTopContext ? 0 : 16,
            left: 20,
            right: 20,
          ),
          sliver: SliverToBoxAdapter(
            child: LargeNoteCard(
              note: root,
              profile: profiles[root.authorPubkey],
              replyCount: replyCount ?? replies.length,
            ),
          ),
        ),

        // ── Replies ───────────────────────────────────────────────────────────
        if (replies.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ThreadEmptyReplies(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(
                left: 20, right: 20, top: 12, bottom: 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final reply = replies[i];
                  return NoteCard(
                    key: ValueKey(reply.id),
                    note: reply,
                    profile: profiles[reply.authorPubkey],
                    replyCount: reply.cachedReplyCount,
                    onTap: () => onOpenThread(reply.id),
                    // Mirrors VishnuFeedBloc._onSave — save then embed so
                    // RAG/graph picks the note up.
                    onSaveTap: () async {
                      final result =
                          await getIt<SaveNoteUseCase>().call(reply);
                      result.fold(
                        (_) {},
                        (saved) {
                          getIt<EmbedAndStoreNoteUseCase>()
                              .call((saved.id, saved.content));
                        },
                      );
                    },
                  );
                },
                childCount: replies.length,
              ),
            ),
          ),
      ],
    );
  }
}
