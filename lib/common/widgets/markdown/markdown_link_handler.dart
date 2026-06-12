import 'package:flutter/material.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/common/widgets/open_user_profile.dart';
import 'package:url_launcher/url_launcher.dart';

/// Routes a tapped link inside rendered note markdown to the right destination.
///
/// Order:
///   1. `nostr:npub1…` / bare `npub1…` → in-app user profile
///   2. anything else                  → external browser
///
/// Example — a note contains:
///   Follow nostr:npub1xtscya34g58tk0z605fvr788k263gsu6cy9x0mrjia9wdcuaqltsd5ku22
/// Tapping that link decodes the npub to a hex pubkey and pushes the user's
/// profile page inside UNIUN — no browser involved.
Future<void> handleMarkdownLink(BuildContext context, String href) async {
  final raw = href.trim();
  if (raw.isEmpty) return;

  final stripped = raw.startsWith('nostr:') ? raw.substring(6) : raw;
  if (stripped.startsWith('npub1')) {
    try {
      final hex = Nip19.decodePubkey(stripped);
      if (!context.mounted) return;
      openUserProfile(context, hex);
      return;
    } catch (_) {}
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
