import 'package:avatar_plus/avatar_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/core/theme/app_theme.dart';

// AvatarPlus regenerates its SVG string AND re-parses it via SvgPicture on every
// build. A feed card rebuilds several times as its cubit's async profile/saved/
// follow queries resolve, so the same deterministic avatar was being rebuilt
// dozens of times per scroll — a major source of main-thread jank. Memoize the
// generated SVG per seed (FIFO-capped); flutter_svg's own picture cache then
// dedupes the parse, so a repeat seed costs only a map lookup.
const int _kAvatarSvgCacheCap = 256;
final Map<String, String> _avatarSvgCache = <String, String>{};

String _avatarSvg(String seed) {
  final cached = _avatarSvgCache[seed];
  if (cached != null) return cached;
  final svg = AvatarPlusGen.instance.generate(seed, trBackground: false);
  if (_avatarSvgCache.length >= _kAvatarSvgCacheCap) {
    _avatarSvgCache.remove(_avatarSvgCache.keys.first);
  }
  _avatarSvgCache[seed] = svg;
  return svg;
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.seed,
    this.photoUrl,
    this.size = 40,
    this.borderRadius,
    this.showBorder = false,
    this.onTap,
  });

  final String seed;
  final String? photoUrl;
  final double size;
  final double? borderRadius;
  final bool showBorder;

  /// When non-null, the avatar becomes tappable. Callers wire this to navigate
  /// to the user's profile (see [openUserProfileFromPubkey] for the canonical
  /// invocation).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size / 2;
    // Decode network avatars at display resolution, not the source's full size.
    final decodePx = (size * MediaQuery.devicePixelRatioOf(context)).round();

    // 'generated:<seed>' prefix means the user picked an avatar variant during
    // onboarding. Use that seed directly for AvatarPlus instead of the pubkey.
    final isGeneratedVariant =
        photoUrl != null && photoUrl!.startsWith('generated:');
    final isNetwork = !isGeneratedVariant &&
        photoUrl != null &&
        photoUrl!.isNotEmpty &&
        (photoUrl!.startsWith('http://') || photoUrl!.startsWith('https://'));

    // Which seed to pass into AvatarPlus when no real photo is available.
    final generatedSeed = isGeneratedVariant
        ? photoUrl!.substring('generated:'.length)
        : (seed.isEmpty ? AppConstants.kAppName : seed);

    final container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.35),
                width: 1.5,
              )
            : null,
        color: AppColors.surfaceContainerLow,
      ),
      clipBehavior: Clip.antiAlias,
      child: isNetwork
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              memCacheWidth: decodePx,
              memCacheHeight: decodePx,
              placeholder: (_, __) => _generated(generatedSeed),
              errorWidget: (_, __, ___) => _generated(generatedSeed),
            )
          : _generated(generatedSeed),
    );
    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: container,
    );
  }

  Widget _generated(String s) => SvgPicture.string(
        _avatarSvg(s),
        width: size,
        height: size,
      );
}
