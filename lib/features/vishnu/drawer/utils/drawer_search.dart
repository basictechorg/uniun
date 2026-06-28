import 'package:uniun/features/vishnu/drawer/bloc/drawer_bloc.dart';

/// The surface a drawer search hit belongs to. Drives both the leading type
/// icon and the navigation target of a result row.
enum DrawerSearchKind { group, privateGroup, dm, followedNote, followedUser }

/// A single match in the unified drawer search list. [id] is the surface's
/// natural identifier — groupId / groupId / pubkey / eventId — carried
/// through so the row can reuse the existing per-surface navigation.
class DrawerSearchResult {
  const DrawerSearchResult({
    required this.kind,
    required this.id,
    required this.label,
    this.avatarUrl,
    this.hasUnread = false,
  });

  final DrawerSearchKind kind;
  final String id;
  final String label;
  final String? avatarUrl;
  final bool hasUnread;
}

/// Client-side filter over the lists already held in [DrawerLoaded]. Plain
/// case-insensitive substring match on each item's visible label. A blank /
/// whitespace-only query yields no results (the caller shows the normal
/// sectioned drawer instead).
List<DrawerSearchResult> buildDrawerSearchResults(
  DrawerLoaded state,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  bool match(String text) => text.toLowerCase().contains(q);

  return [
    for (final c in state.groups)
      if (match(c.name))
        DrawerSearchResult(
          kind: DrawerSearchKind.group,
          id: c.id,
          label: c.name,
          hasUnread: c.hasUnread,
        ),
    for (final c in state.privateGroups)
      if (match(c.name))
        DrawerSearchResult(
          kind: DrawerSearchKind.privateGroup,
          id: c.id,
          label: c.name,
          hasUnread: c.hasUnread,
        ),
    for (final d in state.dms)
      if (match(d.name))
        DrawerSearchResult(
          kind: DrawerSearchKind.dm,
          id: d.pubkey,
          label: d.name,
          avatarUrl: d.avatarUrl,
          hasUnread: d.unreadCount > 0,
        ),
    for (final n in state.followedNotes)
      if (match(n.contentPreview))
        DrawerSearchResult(
          kind: DrawerSearchKind.followedNote,
          id: n.eventId,
          label: n.contentPreview,
          hasUnread: n.newReferenceCount > 0,
        ),
    for (final u in state.followedUsers)
      if (match(u.name))
        DrawerSearchResult(
          kind: DrawerSearchKind.followedUser,
          id: u.pubkey,
          label: u.name,
          avatarUrl: u.avatarUrl,
        ),
  ];
}
