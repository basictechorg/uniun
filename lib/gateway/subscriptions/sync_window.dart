/// Rolling window for bulk relay pulls (channel/group messages, feed notes).
///
/// Followed notes, DMs, and the MLS control plane are intentionally exempt and
/// pull full history. This is the single source of truth for the window length.
const Duration kRecentSyncWindow = Duration(days: 7);

/// `since` bound (unix seconds) for a recent-window filter over [window],
/// computed fresh per subscribe so the window rolls forward on every
/// (re)connect.
int recentSyncSinceEpochSeconds(Duration window) =>
    DateTime.now().subtract(window).millisecondsSinceEpoch ~/ 1000;
