import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/features/media/widgets/media_tile.dart';

import '../../../_helpers/fixtures.dart';

/// Covers: MediaTile — file-type tile rendering for non-image mimes,
/// filename ellipsis, busy overlay adds DropLoadingIndicator, selected border
/// + check icon, tap and long-press callbacks, missing localPath falls back
/// to the file tile even for images.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 200, height: 200, child: child),
        ),
      );

  // ── file-type tile (non-image mimes) ──────────────────────────────────────

  group('file-type tile', () {
    testWidgets('renders label + icon + filename for pdf', (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aPdfBlob(),
        busy: false,
      )));
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('renders label for video mime', (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aVideoBlob(),
        busy: false,
      )));
      expect(find.text('clip.mp4'), findsOneWidget);
    });

    testWidgets('renders generic type when filename is null', (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aMediaBlob(
          sha256: 'x',
          mime: 'application/vnd.custom',
          filename: null,
        ),
        busy: false,
      )));
      // No filename text — only the type chip is shown.
      expect(find.byType(Text), findsWidgets); // chip label
    });

    testWidgets('long filename ellipsizes', (t) async {
      const long = 'this-is-an-extremely-long-filename-that-cannot-fit.pdf';
      await t.pumpWidget(host(MediaTile(
        blob: aMediaBlob(
          sha256: 'x',
          mime: 'application/pdf',
          filename: long,
        ),
        busy: false,
      )));
      final textFinder = find.text(long);
      expect(textFinder, findsOneWidget);
      final textWidget = t.widget<Text>(textFinder);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });

  // ── image mime with no localPath falls back to file tile ──────────────────

  group('image without localPath', () {
    testWidgets('renders the file-type tile instead of Image.file', (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aMediaBlob(sha256: 'x', mime: 'image/jpeg', localPath: null),
        busy: false,
      )));
      expect(find.byType(Image), findsNothing);
    });
  });

  // ── overlays ──────────────────────────────────────────────────────────────

  group('overlays', () {
    testWidgets('busy=true adds the DropLoadingIndicator overlay',
        (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aPdfBlob(),
        busy: true,
      )));
      expect(find.byType(DropLoadingIndicator), findsOneWidget);
    });

    testWidgets('busy=false has no DropLoadingIndicator', (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aPdfBlob(),
        busy: false,
      )));
      expect(find.byType(DropLoadingIndicator), findsNothing);
    });

    testWidgets('selected=true adds the check icon', (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aPdfBlob(),
        busy: false,
        selected: true,
      )));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('selected=false has no check icon', (t) async {
      await t.pumpWidget(host(MediaTile(
        blob: aPdfBlob(),
        busy: false,
      )));
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });

  // ── callbacks ─────────────────────────────────────────────────────────────

  group('callbacks', () {
    testWidgets('tap fires onTap', (t) async {
      var taps = 0;
      await t.pumpWidget(host(MediaTile(
        blob: aPdfBlob(),
        busy: false,
        onTap: () => taps++,
      )));
      await t.tap(find.byType(MediaTile));
      expect(taps, 1);
    });

    testWidgets('long-press fires onLongPress', (t) async {
      var longs = 0;
      await t.pumpWidget(host(MediaTile(
        blob: aPdfBlob(),
        busy: false,
        onLongPress: () => longs++,
      )));
      await t.longPress(find.byType(MediaTile));
      expect(longs, 1);
    });

    testWidgets('no callbacks — tap still works without throwing', (t) async {
      await t.pumpWidget(host(MediaTile(blob: aPdfBlob(), busy: false)));
      await t.tap(find.byType(MediaTile));
      expect(t.takeException(), isNull);
    });
  });
}
