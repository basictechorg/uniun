import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/followed_notes/cubit/followed_notes_cubit.dart';
import 'package:uniun/features/thread/bloc/thread_bloc.dart';
import 'package:uniun/features/thread/widgets/thread_app_bar.dart';
import 'package:uniun/features/thread/widgets/thread_empty_states.dart';
import 'package:uniun/common/widgets/thread/message_thread_page.dart';

/// Route argument for [ThreadPage]. Pass either a plain [String] (eventId) or a
/// [ThreadRouteArgs] when the thread should filter to saved notes only.
class ThreadRouteArgs {
  const ThreadRouteArgs(this.noteId, {this.savedOnly = false});
  final String noteId;
  final bool savedOnly;
}

/// The single thread screen for every note, regardless of which collection
/// holds it. [ThreadBloc] resolves the id across all collections.
class ThreadPage extends StatelessWidget {
  const ThreadPage({super.key, required this.noteId, this.savedOnly = false});
  final String noteId;
  final bool savedOnly;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<ThreadBloc>()
            ..add(LoadThreadEvent(noteId, savedOnly: savedOnly)),
        ),
        BlocProvider(
          create: (_) => getIt<FollowedNotesCubit>()..load(),
        ),
      ],
      child: _ThreadView(noteId: noteId),
    );
  }
}

class _ThreadView extends StatefulWidget {
  const _ThreadView({required this.noteId});
  final String noteId;

  @override
  State<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<_ThreadView> {
  // Note ids currently open as a ThreadPage anywhere in the stack — prevents
  // pushing a duplicate of a page that already exists in the back stack.
  static final Set<String> _openNoteIds = {};

  @override
  void initState() {
    super.initState();
    _openNoteIds.add(widget.noteId);
  }

  @override
  void dispose() {
    _openNoteIds.remove(widget.noteId);
    super.dispose();
  }

  void _openThread(BuildContext ctx, String noteId) {
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
    final savedOnly = bloc.state.savedOnly;
    final args = savedOnly ? ThreadRouteArgs(noteId, savedOnly: true) : noteId;
    // Reload this thread when the child pops so new nested replies are reflected.
    Navigator.pushNamed(ctx, AppRoutes.thread, arguments: args).then((_) {
      if (mounted) {
        bloc.add(LoadThreadEvent(widget.noteId, savedOnly: savedOnly));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ThreadBloc, ThreadState>(
      listenWhen: (prev, curr) => prev.postStatus != curr.postStatus,
      listener: (context, state) {
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
        if (state.status == ThreadStatus.loading ||
            state.status == ThreadStatus.initial) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
            appBar: ThreadAppBar(),
            body: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          );
        }
        if (state.status == ThreadStatus.error || state.rootNote == null) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: const ThreadAppBar(),
            body: ThreadErrorBody(
                message: state.errorMessage ?? 'Failed to load thread'),
          );
        }

        final bloc = context.read<ThreadBloc>();
        // Notes available to reference from the composer — everything visible in
        // this thread, de-duplicated (the root itself is already the reply target).
        final seen = <String>{state.rootNote!.id};
        final referenceCandidates = [
          ...state.parentNotes,
          ...state.mentionedNotes,
          ...state.replies,
        ].where((n) => seen.add(n.id)).toList();

        return MessageThreadPage(
          appBar: const ThreadAppBar(),
          root: state.rootNote!,
          profiles: state.profiles,
          parentNotes: state.parentNotes,
          mentionedNotes: state.mentionedNotes,
          replies: state.replies,
          replyCount: state.replies.length,
          isSending: state.postStatus == ThreadPostStatus.posting,
          referenceCandidates: referenceCandidates,
          onSendReply: (text, refs) =>
              bloc.add(PostReplyEvent(text, mentionRefs: refs)),
          onOpenThread: (id) => _openThread(context, id),
        );
      },
    );
  }
}
