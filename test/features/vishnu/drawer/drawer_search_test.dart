import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/vishnu/drawer/bloc/drawer_bloc.dart';
import 'package:uniun/features/vishnu/drawer/utils/drawer_search.dart';

DrawerLoaded _state({
  List<DrawerChannelItem> channels = const [],
  List<DrawerPrivateChannelItem> privateChannels = const [],
  List<DrawerDmItem> dms = const [],
  List<DrawerFollowedNoteItem> followedNotes = const [],
  List<DrawerFollowedUserItem> followedUsers = const [],
}) {
  return DrawerLoaded(
    userName: 'me',
    npub: 'npub',
    pubkeyHex: 'hex',
    followedNotes: followedNotes,
    channels: channels,
    privateChannels: privateChannels,
    dms: dms,
    followedUsers: followedUsers,
    myRelays: const [],
  );
}

void main() {
  group('buildDrawerSearchResults', () {
    test('blank query returns no results', () {
      final state = _state(
        channels: const [DrawerChannelItem(id: 'c1', name: 'general')],
      );
      expect(buildDrawerSearchResults(state, ''), isEmpty);
      expect(buildDrawerSearchResults(state, '   '), isEmpty);
    });

    test('matches across every list, case-insensitively', () {
      final state = _state(
        channels: const [
          DrawerChannelItem(id: 'c1', name: 'Alice-dev'),
          DrawerChannelItem(id: 'c2', name: 'random'),
        ],
        privateChannels: const [
          DrawerPrivateChannelItem(id: 'g1', name: 'alice private'),
        ],
        dms: const [DrawerDmItem(pubkey: 'p1', name: 'ALICE')],
        followedNotes: const [
          DrawerFollowedNoteItem(eventId: 'e1', contentPreview: "alice's note"),
          DrawerFollowedNoteItem(eventId: 'e2', contentPreview: 'unrelated'),
        ],
        followedUsers: const [
          DrawerFollowedUserItem(pubkey: 'p2', name: 'Alice Johnson'),
        ],
      );

      final results = buildDrawerSearchResults(state, 'alice');
      final kinds = results.map((r) => r.kind).toSet();

      expect(results, hasLength(5));
      expect(kinds, {
        DrawerSearchKind.channel,
        DrawerSearchKind.privateChannel,
        DrawerSearchKind.dm,
        DrawerSearchKind.followedNote,
        DrawerSearchKind.followedUser,
      });
      // identifiers are carried through for navigation
      final channel = results.firstWhere((r) => r.kind == DrawerSearchKind.channel);
      expect(channel.id, 'c1');
      expect(channel.label, 'Alice-dev');
    });

    test('no match yields empty list', () {
      final state = _state(
        channels: const [DrawerChannelItem(id: 'c1', name: 'general')],
      );
      expect(buildDrawerSearchResults(state, 'zzz'), isEmpty);
    });

    test('carries unread / new-reference flags', () {
      final state = _state(
        channels: const [
          DrawerChannelItem(id: 'c1', name: 'news', hasUnread: true),
        ],
        followedNotes: const [
          DrawerFollowedNoteItem(
              eventId: 'e1', contentPreview: 'news note', newReferenceCount: 3),
        ],
      );
      final results = buildDrawerSearchResults(state, 'news');
      expect(results.every((r) => r.hasUnread), isTrue);
    });
  });
}
