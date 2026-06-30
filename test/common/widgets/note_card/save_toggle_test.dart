import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/common/widgets/note_card/save_toggle.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';

import '../../../_helpers/fixtures.dart';

class _MockCubit extends MockCubit<NoteCardState> implements NoteCardCubit {}

NoteEntity _note() => aNote(id: 'n', authorPubkey: 'p', content: 'c');

ManasEntity _m(String id) => aManas(manasId: id, name: id, noteCount: 1);

/// Decision tree:
///   not saved        → toggleSave
///   saved, no manas  → toggleSave
///   saved, has manas → confirm dialog → confirm: unsaveWithManasRemoval;
///                      cancel: no write
void main() {
  late _MockCubit cubit;

  setUp(() {
    cubit = _MockCubit();
    when(() => cubit.note).thenReturn(_note());
    when(() => cubit.manasesContainingNote())
        .thenAnswer((_) async => const <ManasEntity>[]);
    when(() => cubit.toggleSave()).thenAnswer((_) async {});
    when(() => cubit.unsaveWithManasRemoval(any())).thenAnswer((_) async {});
  });

  Widget host() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => handleSaveToggle(ctx, cubit),
            child: const Text('toggle'),
          ),
        ),
      ),
    );
  }

  testWidgets('not saved: toggleSave called, no dialog shown', (t) async {
    when(() => cubit.state).thenReturn(const NoteCardState(isSaved: false));
    await t.pumpWidget(host());
    await t.tap(find.text('toggle'));
    await t.pumpAndSettle();
    verify(() => cubit.toggleSave()).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('saved + no manas memberships: toggleSave, no dialog',
      (t) async {
    when(() => cubit.state).thenReturn(const NoteCardState(isSaved: true));
    when(() => cubit.manasesContainingNote())
        .thenAnswer((_) async => const <ManasEntity>[]);
    await t.pumpWidget(host());
    await t.tap(find.text('toggle'));
    await t.pumpAndSettle();
    verify(() => cubit.toggleSave()).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('saved + manas memberships: confirm dialog appears', (t) async {
    when(() => cubit.state).thenReturn(const NoteCardState(isSaved: true));
    when(() => cubit.manasesContainingNote())
        .thenAnswer((_) async => [_m('work'), _m('research')]);
    await t.pumpWidget(host());
    await t.tap(find.text('toggle'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    // Both Manas cards visible inside the dialog.
    expect(find.text('work'), findsOneWidget);
    expect(find.text('research'), findsOneWidget);
  });

  testWidgets('confirm path: calls unsaveWithManasRemoval with all ids',
      (t) async {
    when(() => cubit.state).thenReturn(const NoteCardState(isSaved: true));
    when(() => cubit.manasesContainingNote())
        .thenAnswer((_) async => [_m('a'), _m('b')]);
    await t.pumpWidget(host());
    await t.tap(find.text('toggle'));
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await t.tap(find.text(l10n.unsaveManasDialogConfirm));
    await t.pumpAndSettle();
    verify(() => cubit.unsaveWithManasRemoval(['a', 'b'])).called(1);
    verifyNever(() => cubit.toggleSave());
  });

  testWidgets('cancel path: no write performed', (t) async {
    when(() => cubit.state).thenReturn(const NoteCardState(isSaved: true));
    when(() => cubit.manasesContainingNote())
        .thenAnswer((_) async => [_m('a')]);
    await t.pumpWidget(host());
    await t.tap(find.text('toggle'));
    await t.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await t.tap(find.text(l10n.unsaveManasDialogCancel));
    await t.pumpAndSettle();
    verifyNever(() => cubit.unsaveWithManasRemoval(any()));
    verifyNever(() => cubit.toggleSave());
  });
}
