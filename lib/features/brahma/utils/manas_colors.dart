import 'package:flutter/material.dart';

/// Curated swatch palette + stable hash util for per-Manas node colouring.
///
/// • [palette] — the 16 swatches the picker shows. Hex strings are stored on
///   `ManasModel.colorHexes`, so any rename here is a data concern.
/// • [colorFor] — resolves a node's tint from a Manas's palette using a
///   stable hash of the eventId, so the same note always paints the same
///   colour across re-renders (no flicker on rebuilds).
///
/// Unscoped Brahma never calls into this — the default
/// saved/own/draft colours from `app_theme.dart` are unchanged. Only
/// Manas-scoped graphs apply an override.
abstract class ManasColors {
  /// 16 swatches — restrained and high-contrast on white. Order matters
  /// only for the picker grid; the stable hash is symmetric.
  static const List<String> palette = [
    '#3B82F6', // blue
    '#0EA5E9', // sky
    '#06B6D4', // cyan
    '#14B8A6', // teal
    '#10B981', // emerald
    '#22C55E', // green
    '#84CC16', // lime
    '#EAB308', // yellow
    '#F59E0B', // amber
    '#F97316', // orange
    '#EF4444', // red
    '#EC4899', // pink
    '#D946EF', // fuchsia
    '#A855F7', // purple
    '#6366F1', // indigo
    '#64748B', // slate
  ];

  /// Parses a `#RRGGBB` hex string. Falls back to a neutral grey on any
  /// malformed input — never throws.
  static Color parse(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return const Color(0xFF94A3B8);
    final v = int.tryParse(clean, radix: 16);
    if (v == null) return const Color(0xFF94A3B8);
    return Color(0xFF000000 | v);
  }

  /// Picks the node colour from [hexes] using a stable hash of [eventId].
  /// Returns null when [hexes] is empty (caller falls back to the default
  /// type colour). Always deterministic — same note → same colour.
  static Color? colorFor(String eventId, List<String> hexes) {
    if (hexes.isEmpty) return null;
    if (hexes.length == 1) return parse(hexes.first);
    final idx = _stableHash(eventId) % hexes.length;
    return parse(hexes[idx]);
  }

  /// FNV-1a over the eventId bytes — fast, no dep, well-distributed across
  /// small bucket counts (2 or 3).
  static int _stableHash(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
