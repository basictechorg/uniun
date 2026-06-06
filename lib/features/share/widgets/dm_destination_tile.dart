import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
import 'package:uniun/features/share/widgets/destination_tile.dart';

/// DM destination row that resolves the peer's profile name + avatar from
/// Isar via [ProfileRepository]. Falls back to a truncated pubkey when no
/// profile is stored locally.
class DmDestinationTile extends StatefulWidget {
  const DmDestinationTile({
    super.key,
    required this.otherPubkeyHex,
    required this.onTap,
  });

  final String otherPubkeyHex;
  final VoidCallback onTap;

  @override
  State<DmDestinationTile> createState() => _DmDestinationTileState();
}

class _DmDestinationTileState extends State<DmDestinationTile> {
  String? _name;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await getIt<ProfileRepository>().getProfile(widget.otherPubkeyHex);
    if (!mounted) return;
    setState(() {
      _name = result.fold<String?>(
        (_) => null,
        (p) => p.name ?? p.username,
      );
      _avatarUrl = result.fold<String?>((_) => null, (p) => p.avatarUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DestinationTile(
      leading: UserAvatar(
        seed: widget.otherPubkeyHex,
        photoUrl: _avatarUrl,
        size: 36,
        borderRadius: 18,
      ),
      title: _name ?? _shortPubkey(widget.otherPubkeyHex),
      onTap: widget.onTap,
    );
  }

  String _shortPubkey(String pk) => pk.length <= 16
      ? pk
      : '${pk.substring(0, 8)}…${pk.substring(pk.length - 4)}';
}
