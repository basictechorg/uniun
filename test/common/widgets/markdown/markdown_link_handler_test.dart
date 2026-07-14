import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/common/widgets/markdown/markdown_link_handler.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/features/profile/pages/user_profile_page.dart';

import '../../../_helpers/fixtures.dart';

/// Covers: handleMarkdownLink routing — npub / nostr:npub links open the
/// in-app profile, malformed input is a safe no-op. (The external-browser
/// branch is a one-line url_launcher delegation, untested here.)
void main() {
  UserProfileArgs? pushedArgs;

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    pushedArgs = null;
    late BuildContext ctx;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) {
          ctx = context;
          return const SizedBox();
        },
      ),
      GoRoute(
        path: '/user-profile',
        name: AppRoutes.userProfile,
        builder: (context, state) {
          pushedArgs = state.extra as UserProfileArgs?;
          return const SizedBox();
        },
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    return ctx;
  }

  testWidgets('bare npub link opens the in-app profile with the hex pubkey',
      (tester) async {
    final ctx = await pumpHost(tester);
    final npub = Nip19.encodePubkey(kSampleTargetPubkeyHex);

    await handleMarkdownLink(ctx, npub);
    await tester.pumpAndSettle();

    expect(pushedArgs?.pubkeyHex, kSampleTargetPubkeyHex);
  });

  testWidgets('nostr:npub scheme routes the same way', (tester) async {
    final ctx = await pumpHost(tester);
    final npub = Nip19.encodePubkey(kSampleTargetPubkeyHex);

    await handleMarkdownLink(ctx, 'nostr:$npub');
    await tester.pumpAndSettle();

    expect(pushedArgs?.pubkeyHex, kSampleTargetPubkeyHex);
  });

  testWidgets('whitespace around the link is tolerated', (tester) async {
    final ctx = await pumpHost(tester);
    final npub = Nip19.encodePubkey(kSampleTargetPubkeyHex);

    await handleMarkdownLink(ctx, '  $npub \n');
    await tester.pumpAndSettle();

    expect(pushedArgs?.pubkeyHex, kSampleTargetPubkeyHex);
  });

  testWidgets('empty and scheme-less garbage are safe no-ops',
      (tester) async {
    final ctx = await pumpHost(tester);

    await handleMarkdownLink(ctx, '');
    await handleMarkdownLink(ctx, '   ');
    await handleMarkdownLink(ctx, 'just some words');
    await handleMarkdownLink(ctx, 'npub1notavalidbech32string');
    await tester.pumpAndSettle();

    expect(pushedArgs, isNull);
  });
}
