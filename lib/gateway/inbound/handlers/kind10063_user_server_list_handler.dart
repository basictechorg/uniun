import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/user_server_list_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 10063 — BUD-03 user server list. Replaceable per-pubkey; we keep
/// only the active user's row, reconciled last-write-wins by `created_at`.
class Kind10063UserServerListHandler implements KindHandler {
  Kind10063UserServerListHandler({required this.activePubkey});

  final String? activePubkey;

  @override
  Set<int> get kinds => const {10063};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final pubkey = event['pubkey'] as String?;
    final createdAtSec = event['created_at'] as int?;
    if (pubkey == null || createdAtSec == null) return;
    if (pubkey != activePubkey) return;

    final createdAt = EventParser.dateTimeFromSec(createdAtSec);
    final tags = event['tags'] as List<dynamic>? ?? const [];
    final servers = <String>[];
    for (final raw in tags) {
      if (raw is! List || raw.length < 2) continue;
      if (raw[0] != 'server') continue;
      final url = raw[1];
      if (url is String && url.isNotEmpty) servers.add(url);
    }

    try {
      await isar.writeTxn(() async {
        final row = (await isar.userServerListModels.get(0)) ??
            UserServerListModel();
        final last = row.lastSyncedCreatedAt;
        if (last != null && !createdAt.isAfter(last)) return;
        row.serverUrls = servers;
        row.lastSyncedCreatedAt = createdAt;
        await isar.userServerListModels.put(row);
      });
    } catch (_) {
      // Best-effort — local snapshot is non-critical.
    }
  }
}
