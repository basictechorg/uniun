import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
import 'package:uniun/features/share/widgets/destination_tile.dart';

/// DM row — resolves peer name/avatar; falls back to short pubkey.
class DmDestinationTile extends StatefulWidget {
  const DmDestinationTile({
    super.key,
    required this.otherPubkeyHex,
    required this.onTap,
    this.selected = false,
  });

  final String otherPubkeyHex;
  final VoidCallback onTap;
  final bool selected;

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
        size: 38,
        borderRadius: 19,
      ),
      title: _name ?? _shortPubkey(widget.otherPubkeyHex),
      onTap: widget.onTap,
      selected: widget.selected,
    );
  }

  String _shortPubkey(String pk) => pk.length <= 16
      ? pk
      : '${pk.substring(0, 8)}…${pk.substring(pk.length - 4)}';
}
