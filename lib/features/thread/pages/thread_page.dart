import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/followed_notes/cubit/followed_notes_cubit.dart';
import 'package:uniun/features/thread/bloc/thread_bloc.dart';
import 'package:uniun/features/thread/widgets/thread_app_bar.dart';
import 'package:uniun/features/thread/widgets/thread_empty_states.dart';
import 'package:uniun/features/thread/widgets/thread_parent_context.dart';
import 'package:uniun/features/thread/widgets/thread_reply_composer.dart';
import 'package:uniun/features/thread/widgets/thread_reply_item.dart';
import 'package:uniun/features/thread/widgets/thread_root_note_card.dart';

/// Route argument for [ThreadPage]. Pass either a plain [String] (eventId)
/// or a [ThreadRouteArgs] when opening from a followed note with unread state.
class ThreadRouteArgs {
  const ThreadRouteArgs(this.noteId, {this.hasUnread = false, this.savedOnly = false});
  final String noteId;
  final bool hasUnread;
  final bool savedOnly;
}

class ThreadPage extends StatelessWidget {
  const ThreadPage({super.key, required this.noteId, this.savedOnly = false, this.hasUnread = false});
  final String noteId;
  final bool savedOnly;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<ThreadBloc>()
            ..add(LoadThreadEvent(noteId, savedOnly: savedOnly, hasUnread: hasUnread)),
        ),
        BlocProvider(
          create: (_) => getIt<FollowedNotesCubit>()..load(),
        ),
      ],
      child: _ThreadView(noteId: noteId),
    );
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

class _ThreadView extends StatefulWidget {
  const _ThreadView({required this.noteId});
  final String noteId;

  @override
  State<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<_ThreadView> {
  // Tracks all noteIds currently open as a ThreadPage anywhere in the stack.
  // Prevents pushing a duplicate of a page that already exists in the back stack.
  static final Set<String> _openNoteIds = {};

  final _replyController = TextEditingController();
  final _focusNode = FocusNode();
  String? _avatarUrl;
  String _pubkeySeed = '';

  @override
  void initState() {
    super.initState();
    _openNoteIds.add(widget.noteId);
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final result = await getIt<GetActiveUserProfileUseCase>().call();
    result.fold((_) {}, (userProfile) {
      if (mounted) {
        setState(() {
          _pubkeySeed = userProfile.pubkeyHex;
          _avatarUrl = userProfile.avatarUrl;
        });
      }
    });
  }

  void _openThread(BuildContext ctx, String noteId) {
    // If this noteId is already open somewhere in the back stack, pop back to
    // it instead of creating a duplicate page.
    if (_openNoteIds.contains(noteId)) {
      Navigator.of(ctx).popUntil((route) {
        final args = route.settings.arguments;
        final id = args is String
            ? args
            : args is ThreadRouteArgs
                ? args.noteId
                : null;
        return id == noteId || route.isFirst;
      });
      return;
    }
    final bloc = context.read<ThreadBloc>();
    // Propagate savedOnly so child threads also filter to saved notes only.
    final args = bloc.state.savedOnly
        ? ThreadRouteArgs(noteId, savedOnly: true)
        : noteId as Object;
    // Reload this thread when the child thread is popped so reply counts and
    // newly created nested replies are reflected without a manual refresh.
    Navigator.pushNamed(ctx, AppRoutes.thread, arguments: args).then((_) {
      if (mounted) bloc.add(LoadThreadEvent(widget.noteId, savedOnly: bloc.state.savedOnly));
    });
  }

  @override
  void dispose() {
    _openNoteIds.remove(widget.noteId);
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ThreadBloc, ThreadState>(
      listener: (context, state) {
        if (state.postStatus == ThreadPostStatus.posted) {
          _replyController.clear();
          _focusNode.unfocus();
        }
        if (state.postStatus == ThreadPostStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: AppColors.surface,
            appBar: const ThreadAppBar(),
            body: switch (state.status) {
              ThreadStatus.loading || ThreadStatus.initial => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              ThreadStatus.error => ThreadErrorBody(
                  message: state.errorMessage ?? 'Failed to load thread'),
              _ => _ThreadBody(
                  state: state,
                  focusNode: _focusNode,
                  onOpenThread: _openThread,
                ),
            },
            bottomNavigationBar: ThreadReplyComposer(
              controller: _replyController,
              focusNode: _focusNode,
              avatarUrl: _avatarUrl,
              pubkeySeed: _pubkeySeed,
              canPost: state.canPost,
              isSending: state.postStatus == ThreadPostStatus.posting,
              replyingToName: state.replyingToName,
              onSend: () => context.read<ThreadBloc>().add(const PostReplyEvent()),
              onClearReply: () => context.read<ThreadBloc>().add(const SetReplyTargetEvent()),
              onTextChanged: (v) => context.read<ThreadBloc>().add(UpdateReplyTextEvent(v)),
            ),
          ),
        );
      },
    );
  }
}

// ── Body — scroll + sliver layout ────────────────────────────────────────────

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({
    required this.state,
    required this.focusNode,
    required this.onOpenThread,
  });
  final ThreadState state;
  final FocusNode focusNode;
  final void Function(BuildContext, String) onOpenThread;

  @override
  Widget build(BuildContext context) {
    final root = state.rootNote!;

    final hasTopContext =
        state.parentChain.isNotEmpty || state.mentionedNotes.isNotEmpty;

    return CustomScrollView(
      slivers: [
        // ── Immediate NIP-10 parent (1 level only) ────────────────────────────
        if (state.parentChain.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
            sliver: SliverToBoxAdapter(
              child: ThreadParentContext(
                notes: state.parentChain,
                profiles: state.profiles,
                onNoteTap: (noteId) => onOpenThread(context, noteId),
              ),
            ),
          ),

        // ── Outgoing references — rendered as sibling "parents" above the
        //    root note. Each referenced note is an independent sibling; only
        //    the last row connects down to the root card. ─────────────────────
        if (state.mentionedNotes.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(
                top: state.parentChain.isEmpty ? 16 : 0, left: 20, right: 20),
            sliver: SliverToBoxAdapter(
              child: ThreadParentContext(
                notes: state.mentionedNotes,
                profiles: state.profiles,
                isSiblingGroup: true,
                onNoteTap: (noteId) => onOpenThread(context, noteId),
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
            child: ThreadRootNoteCard(
              note: root,
              profile: state.profileFor(root.authorPubkey),
              replyCount: state.replies.length,
            ),
          ),
        ),

        // ── Replies ───────────────────────────────────────────────────────────
        if (state.replies.isEmpty)
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
                  final reply = state.replies[i];
                  final name = state.profileFor(reply.authorPubkey)?.name ??
                      reply.authorPubkey.substring(0, 8);
                  return ThreadReplyItem(
                    key: ValueKey(reply.id),
                    reply: reply,
                    profile: state.profileFor(reply.authorPubkey),
                    nestedReplies: state.nestedReplies[reply.id] ?? [],
                    nestedProfiles: state.profiles,
                    allNestedReplies: state.nestedReplies,
                    showThreadLine: i < state.replies.length - 1,
                    hasUnread: state.hasUnread,
                    onReplyTap: () {
                      ctx.read<ThreadBloc>().add(
                            SetReplyTargetEvent(
                                replyToId: reply.id, replyToName: name),
                          );
                      focusNode.requestFocus();
                    },
                    onExpandReplies: (id) =>
                        ctx.read<ThreadBloc>().add(ExpandReplyEvent(id)),
                    onNestedReplyTap: (id, nestedName) {
                      ctx.read<ThreadBloc>().add(SetReplyTargetEvent(
                            replyToId: id,
                            replyToName: nestedName,
                          ));
                      focusNode.requestFocus();
                    },
                    // Tapping the content area opens the reply's own thread view
                    onTap: () => onOpenThread(ctx, reply.id),
                  );
                },
                childCount: state.replies.length,
              ),
            ),
          ),
      ],
    );
  }
}

