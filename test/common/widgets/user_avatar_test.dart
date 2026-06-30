import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/user_avatar.dart';

/// Covers each render branch: plain seed, empty seed, 'generated:' photoUrl,
/// http(s) photoUrl, non-URL photoUrl, tappable vs non-tappable, cache reuse.
void main() {
  testWidgets('plain seed renders an SvgPicture (AvatarPlus glyph)',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: UserAvatar(seed: 'pubkey-hex')),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('empty seed still renders an SvgPicture (app-name fallback)',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: UserAvatar(seed: '')),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('generated:<seed> uses AvatarPlus, not network image',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UserAvatar(
          seed: 'whatever',
          photoUrl: 'generated:42',
        ),
      ),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('http(s):// photoUrl renders a CachedNetworkImage', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UserAvatar(
          seed: 's',
          photoUrl: 'https://example.com/a.jpg',
        ),
      ),
    ));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('photoUrl without scheme is treated as non-network', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UserAvatar(seed: 's', photoUrl: 'a.jpg'),
      ),
    ));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('onTap == null: no InkWell wrapper', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: UserAvatar(seed: 'x')),
    ));
    expect(
      find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('onTap != null: tappable InkWell fires the callback', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UserAvatar(seed: 'x', onTap: () => taps++),
      ),
    ));
    expect(
      find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
    await t.tap(find.byType(UserAvatar));
    await t.pump();
    expect(taps, 1);
  });

  testWidgets('repeat seed hits the AvatarPlus SVG cache (no exception)',
      (t) async {
    // Two avatars with the same seed should both render without crashing —
    // this exercises the FIFO-capped `_avatarSvgCache` cache path.
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(children: [
          UserAvatar(seed: 'dup'),
          UserAvatar(seed: 'dup'),
        ]),
      ),
    ));
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });
}
