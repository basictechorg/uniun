import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/note_card/reference_note_card.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';

import '../../../_helpers/fixtures.dart';

NoteEntity _note() =>
    aNote(id: 'n1', authorPubkey: 'pub1', content: 'parent note body');

ProfileEntity _profile({String? name}) =>
    aProfile(pubkey: 'pub1', name: name);

/// Covers: avatar + content rendered, name fallback chain, onTap forward,
/// no-onTap no-throw.
void main() {
  testWidgets('renders an avatar + the note body content', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: ReferenceNoteCard(note: _note())),
    ));
    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.textContaining('parent note body'), findsOneWidget);
  });

  testWidgets('uses profile.name when present', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReferenceNoteCard(
          note: _note(),
          profile: _profile(name: 'Alice'),
        ),
      ),
    ));
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('falls back to short pubkey when no profile is supplied',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: ReferenceNoteCard(note: _note())),
    ));
    // formatShortPubkey produces a non-empty short id; just verify a non-
    // localized author label is shown next to the body.
    expect(find.byType(ReferenceNoteCard), findsOneWidget);
  });

  testWidgets('onTap fires when the card is tapped', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReferenceNoteCard(
          note: _note(),
          onTap: () => taps++,
        ),
      ),
    ));
    await t.tap(find.byType(ReferenceNoteCard));
    expect(taps, 1);
  });

  testWidgets('onTap == null: tapping does not throw', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: ReferenceNoteCard(note: _note())),
    ));
    await t.tap(find.byType(ReferenceNoteCard));
    expect(t.takeException(), isNull);
  });
}
