import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/note_card/reference_note_card.dart';
import 'package:uniun/common/widgets/note_card/referenced_messages.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../../../_helpers/fixtures.dart';

NoteEntity _n(String id) => aNote(id: id, content: 'body $id');

/// Covers: empty list renders nothing, single available ref → ReferenceNoteCard,
/// null ref → unavailable placeholder, mixed list, onTapRef carries source.
void main() {
  testWidgets('empty refs render nothing (no container at all)', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ReferencedMessages(refs: [], unavailableLabel: 'gone'),
      ),
    ));
    expect(find.byType(ReferenceNoteCard), findsNothing);
    expect(find.text('gone'), findsNothing);
  });

  testWidgets('single available ref renders a ReferenceNoteCard', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReferencedMessages(
          refs: [_n('a')],
          unavailableLabel: 'gone',
        ),
      ),
    ));
    expect(find.byType(ReferenceNoteCard), findsOneWidget);
    expect(find.text('gone'), findsNothing);
  });

  testWidgets('null ref renders the unavailable placeholder', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ReferencedMessages(
          refs: [null],
          unavailableLabel: 'gone-msg',
        ),
      ),
    ));
    expect(find.byType(ReferenceNoteCard), findsNothing);
    expect(find.text('gone-msg'), findsOneWidget);
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
  });

  testWidgets('mixed list shows both available + placeholder', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReferencedMessages(
          refs: [_n('a'), null, _n('b')],
          unavailableLabel: 'gone',
        ),
      ),
    ));
    expect(find.byType(ReferenceNoteCard), findsNWidgets(2));
    expect(find.text('gone'), findsOneWidget);
  });

  testWidgets('tapping an available ref calls onTapRef with that note',
      (t) async {
    NoteEntity? tapped;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReferencedMessages(
          refs: [_n('hit')],
          unavailableLabel: 'gone',
          onTapRef: (n) => tapped = n,
        ),
      ),
    ));
    await t.tap(find.byType(ReferenceNoteCard));
    expect(tapped, isNotNull);
    expect(tapped!.id, 'hit');
  });

  testWidgets('onTapRef==null: tap on the ref card is a no-op', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReferencedMessages(
          refs: [_n('x')],
          unavailableLabel: 'gone',
        ),
      ),
    ));
    await t.tap(find.byType(ReferenceNoteCard));
    expect(t.takeException(), isNull);
  });
}
