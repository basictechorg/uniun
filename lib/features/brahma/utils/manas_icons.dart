import 'package:flutter/material.dart';

/// Curated icon registry for Manases.
///
/// Stored as a plain string on `ManasModel.iconName`; resolved at render
/// time via [byName]. The keyword map drives the auto-suggest in the form
/// — as the user types a Manas name, the first matching keyword wins, and
/// the form re-suggests on every keystroke until the user manually picks
/// from the grid (which pins the choice).
///
/// To add a new icon: add it to [all] *and* (optionally) to [_keywordMap]
/// so it auto-suggests for matching names.
abstract class ManasIcons {
  /// Default icon when no name is set / unknown / no keyword matches.
  static const IconData fallback = Icons.man_3_rounded;

  /// User-pickable icons, keyed by stable string name. The string is what
  /// lands in `ManasModel.iconName`, so any rename here is a data migration.
  static const Map<String, IconData> all = {
    'psychology': Icons.psychology_rounded,
    'account_balance': Icons.account_balance_rounded,
    'savings': Icons.savings_rounded,
    'trending_up': Icons.trending_up_rounded,
    'favorite': Icons.favorite_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'directions_run': Icons.directions_run_rounded,
    'self_improvement': Icons.self_improvement_rounded,
    'restaurant': Icons.restaurant_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'flight': Icons.flight_rounded,
    'directions_car': Icons.directions_car_rounded,
    'menu_book': Icons.menu_book_rounded,
    'school': Icons.school_rounded,
    'code': Icons.code_rounded,
    'terminal': Icons.terminal_rounded,
    'memory': Icons.memory_rounded,
    'palette': Icons.palette_rounded,
    'music_note': Icons.music_note_rounded,
    'movie': Icons.movie_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'work': Icons.work_rounded,
    'business_center': Icons.business_center_rounded,
    'science': Icons.science_rounded,
    'biotech': Icons.biotech_rounded,
    'grass': Icons.grass_rounded,
    'pets': Icons.pets_rounded,
    'family_restroom': Icons.family_restroom_rounded,
    'home': Icons.home_rounded,
    'public': Icons.public_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'star': Icons.star_rounded,
    'bolt': Icons.bolt_rounded,
    'rocket_launch': Icons.rocket_launch_rounded,
    'shield': Icons.shield_rounded,
    'lock': Icons.lock_rounded,
    'camera_alt': Icons.camera_alt_rounded,
    'edit_note': Icons.edit_note_rounded,
    'translate': Icons.translate_rounded,
    'chat_bubble': Icons.chat_bubble_rounded,
  };

  /// Keyword → icon-name suggestion. First substring match wins.
  /// Lowercased substring search against the Manas name.
  static const Map<String, String> _keywordMap = {
    // Money / finance
    'finance': 'account_balance',
    'money': 'account_balance',
    'budget': 'account_balance',
    'bank': 'account_balance',
    'invest': 'trending_up',
    'stock': 'trending_up',
    'crypto': 'trending_up',
    'saving': 'savings',
    // Health / fitness
    'health': 'favorite',
    'medical': 'favorite',
    'doctor': 'favorite',
    'wellness': 'favorite',
    'fitness': 'fitness_center',
    'gym': 'fitness_center',
    'workout': 'fitness_center',
    'exercise': 'fitness_center',
    'run': 'directions_run',
    'yoga': 'self_improvement',
    'meditat': 'self_improvement',
    'mindful': 'self_improvement',
    // Food / drink
    'food': 'restaurant',
    'recipe': 'restaurant',
    'cook': 'restaurant',
    'meal': 'restaurant',
    'coffee': 'local_cafe',
    'cafe': 'local_cafe',
    // Travel / mobility
    'travel': 'flight',
    'trip': 'flight',
    'flight': 'flight',
    'vacation': 'flight',
    'car': 'directions_car',
    'drive': 'directions_car',
    // Learning
    'book': 'menu_book',
    'read': 'menu_book',
    'library': 'menu_book',
    'study': 'school',
    'school': 'school',
    'learn': 'school',
    'course': 'school',
    'language': 'translate',
    // Tech / code
    'code': 'code',
    'program': 'code',
    'dev': 'code',
    'rust': 'code',
    'python': 'code',
    'javascript': 'code',
    'flutter': 'code',
    'dart': 'code',
    'shell': 'terminal',
    'terminal': 'terminal',
    'linux': 'terminal',
    'tech': 'memory',
    'hardware': 'memory',
    'ai': 'memory',
    'ml': 'memory',
    // Creative
    'art': 'palette',
    'design': 'palette',
    'paint': 'palette',
    'draw': 'palette',
    'music': 'music_note',
    'song': 'music_note',
    'movie': 'movie',
    'film': 'movie',
    'game': 'sports_esports',
    'photo': 'camera_alt',
    // Work
    'work': 'work',
    'job': 'work',
    'career': 'work',
    'office': 'business_center',
    'business': 'business_center',
    'startup': 'rocket_launch',
    // Science
    'science': 'science',
    'physics': 'science',
    'chem': 'science',
    'bio': 'biotech',
    'medicine': 'biotech',
    'genet': 'biotech',
    // Nature / pets / home
    'garden': 'grass',
    'plant': 'grass',
    'nature': 'grass',
    'pet': 'pets',
    'dog': 'pets',
    'cat': 'pets',
    'family': 'family_restroom',
    'parent': 'family_restroom',
    'home': 'home',
    'house': 'home',
    'world': 'public',
    'news': 'public',
    'politics': 'public',
    // Misc / abstract
    'idea': 'lightbulb',
    'brainstorm': 'lightbulb',
    'star': 'star',
    'favorite': 'star',
    'energy': 'bolt',
    'productivity': 'bolt',
    'security': 'shield',
    'privacy': 'lock',
    'password': 'lock',
    'note': 'edit_note',
    'journal': 'edit_note',
    'diary': 'edit_note',
    'chat': 'chat_bubble',
  };

  /// Renders the icon for a stored name. Unknown / null falls back.
  static IconData byName(String? iconName) {
    if (iconName == null) return fallback;
    return all[iconName] ?? fallback;
  }

  /// Suggests an icon name from the Manas's name string. Returns null when
  /// no keyword matches — caller can show the fallback then.
  static String? suggestFromName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty) return null;
    for (final entry in _keywordMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// All registry keys, sorted alphabetically — used by the picker grid.
  static List<String> get allNames {
    final keys = all.keys.toList()..sort();
    return keys;
  }
}
