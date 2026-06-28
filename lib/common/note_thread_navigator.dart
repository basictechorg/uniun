import 'package:flutter/material.dart';

/// Opens the thread page for an event id.
///
/// Historically this dispatched between [ThreadPage] and a separate
/// `GroupThreadPage` because group messages lived in a different
/// collection. After the [NoteResolverRepository] refactor, [ThreadPage]
/// resolves Kind-1 notes and Kind-42 group messages uniformly, so this
/// helper is now a thin shim that just delegates to [openAsNote]. It is kept
/// so that the many call sites (drawer, saved notes, feed) don't all need to
/// be touched again when routing changes.
Future<void> openEventThread(
  BuildContext context,
  String eventId, {
  required Future<void> Function() openAsNote,
}) async {
  await openAsNote();
}
