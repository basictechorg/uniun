import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/brahma/utils/publish_chain_dialog.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Widget tests for [showPublishChainSheet] — the bottom sheet the user sees
/// when publishing a draft (or a new note) that links other unpublished
/// drafts.
///
/// The sheet is the single point at which the user decides whether the
/// publish-chain logic runs (`PublishChainChoice.chain`) or the draft refs
/// are silently dropped (`PublishChainChoice.only`); a back-tap returns
/// `cancel`. Each path here is asserted on the returned `Future` value, not
/// on widget structure — that's the actual contract callers depend on.
void main() {
  Widget host(Future<void> Function(BuildContext) onReady) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onReady(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping "Publish whole chain" → PublishChainChoice.chain', (tester) async {
    PublishChainChoice? returned;
    await tester.pumpWidget(host((ctx) async {
      returned = await showPublishChainSheet(ctx, draftCount: 2);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('This note links to other drafts'), findsOneWidget);
    expect(find.text('Publish the whole chain'), findsOneWidget);
    expect(find.text('Publish only this'), findsOneWidget);
    expect(find.text('RECOMMENDED'), findsOneWidget);

    await tester.tap(find.text('Publish the whole chain'));
    await tester.pumpAndSettle();
    expect(returned, PublishChainChoice.chain);
  });

  testWidgets('tapping "Publish only this" → PublishChainChoice.only', (tester) async {
    PublishChainChoice? returned;
    await tester.pumpWidget(host((ctx) async {
      returned = await showPublishChainSheet(ctx, draftCount: 1);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publish only this'));
    await tester.pumpAndSettle();
    expect(returned, PublishChainChoice.only);
  });

  testWidgets('dismissing (tap outside) → PublishChainChoice.cancel', (tester) async {
    PublishChainChoice? returned;
    await tester.pumpWidget(host((ctx) async {
      returned = await showPublishChainSheet(ctx, draftCount: 1);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap on the backdrop area — Flutter's `showModalBottomSheet` dismisses
    // on a tap outside the sheet's content area.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(returned, PublishChainChoice.cancel);
  });

  testWidgets('pluralised subtitle: "1 unpublished draft" for count=1', (tester) async {
    await tester.pumpWidget(host((ctx) async {
      await showPublishChainSheet(ctx, draftCount: 1);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('1 unpublished draft'),
      findsOneWidget,
    );
  });

  testWidgets('pluralised subtitle: "3 unpublished drafts" for count=3', (tester) async {
    await tester.pumpWidget(host((ctx) async {
      await showPublishChainSheet(ctx, draftCount: 3);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('3 unpublished drafts'),
      findsOneWidget,
    );
  });
}
