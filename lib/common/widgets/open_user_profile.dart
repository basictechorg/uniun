import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/features/profile/pages/user_profile_page.dart';

/// Canonical "tap an avatar / name" → push the user profile page.
///
/// Use from anywhere a user appears (NoteCard, LargeNoteCard,
/// EmbeddedNoteCard, drawer rows, message bubbles, etc.) so all entry points
/// land on the same screen with the same args.
void openUserProfile(
  BuildContext context,
  String pubkeyHex, {
  String? hintName,
}) {
  context.pushNamed(
    AppRoutes.userProfile,
    extra: UserProfileArgs(pubkeyHex: pubkeyHex, hintName: hintName),
  );
}
