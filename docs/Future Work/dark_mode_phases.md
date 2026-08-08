# Dark Mode — Approach Decision

> ✅ **Shipped in 2.1.0** (see `CHANGELOG.md`). This document is kept as the historical implementation record of *how* it was migrated, not a proposal for future work — dark mode is live today. (Note: there's a separate, later discussion about possibly *removing* dark mode again in the future — that would be a new decision, not a reason to treat this phased-migration record as stale.)

> **Read this section before touching anything else.** It compares the two approaches we considered and explains why the phased migration is the only one that actually works.

## TL;DR

Use the **phased ColorScheme migration** below. There is **no one-file shortcut** — every alternative breaks `const` constructors or fails to react to runtime theme toggling.

---

## Why the "one-file palette swap" doesn't work

The temptation is to make `AppColors` mutable so flipping a flag swaps the palette without touching the ~250 widget files that already reference `AppColors.primary` directly.

```dart
// Tempting but broken:
abstract class AppColors {
  static Color primary = const Color(0xFF0075f2); // not const anymore
  // …
}
void main() {
  if (isDark) AppColors.primary = const Color(0xFF319BED);
  runApp(...);
}
```

It looks like a 1-file change. In reality it breaks the app in three ways:

1. **`const` constructors stop compiling.** The codebase is full of `const Icon(..., color: AppColors.primary)` and `const TextStyle(color: AppColors.onSurface)`. Drop `const` from `AppColors` and every one of those becomes a compile error — you have to remove `const` from hundreds of widget call sites anyway. The "one file" promise is gone.
2. **Not reactive.** A static palette set in `main()` cannot react to `ThemeCubit.setMode(dark)` mid-session. Toggling the theme would require `runApp(...)` again — the user loses scroll position, draft text, BLoC state, isar streams reconnect.
3. **System brightness changes are dropped.** When the OS switches to dark at sunset, Flutter rebuilds with `Theme.of(context)`. Static fields are oblivious to that signal.

A "partial" middle-ground — keep `AppColors` static but also pass `darkTheme: ThemeData.dark()` to `MaterialApp` — gives you a half-dark app: framework widgets (default `Scaffold`, `AppBar`, ripples) go dark, but every widget reading `AppColors.surface` stays white. Worse than no dark mode because the mismatch looks broken.

**The right path is `Theme.of(context).colorScheme`.** That's reactive, it's how Flutter is meant to be themed, and `const` widgets simply read the color at build time. Migration is mechanical, not creative.

---

## The Goal

**Move every color in the app into `AppTheme`.** `AppColors` is deleted at the end.

Two destinations inside `AppTheme`:

| Color type | Destination | Widget reads it via |
|---|---|---|
| Semantic surface/text colors (`surface`, `onSurface`, `primary`, `outline` …) | `ColorScheme` inside `ThemeData` | `Theme.of(context).colorScheme.surface` |
| Custom brand/data-viz colors (graph nodes, storage bars, dot pattern …) | `AppCustomColors` (`ThemeExtension`) inside `ThemeData` | `Theme.of(context).extension<AppCustomColors>()!.graphNodeOwn` |

Both have **light and dark values defined in one place**. Switching `themeMode` switches everything automatically.

---

## STRICT RULE — Every color lives in the theme

> **No raw `Color(0x...)` hex in any widget file. No `AppColors.*` after Phase 5. If a color does not fit an existing `colorScheme` slot, add it to `AppCustomColors` with both a light and a dark value. Never approximate — a graph node green is not `colorScheme.primary`.**

| Wrong | Right |
|---|---|
| `color: Color(0xFF059669)` inline in a widget | `color: custom.graphNodeOwn` |
| `color: colorScheme.primary` for a graph node "close enough" | `color: custom.graphNodeSaved` |
| `color: colorScheme.surface` for the dot pattern bg "it's similar" | `color: custom.graphDotPattern` |
| New badge color added directly in the widget | Add `badgeBackground` to `AppCustomColors` light + dark, then use `custom.badgeBackground` |

---

## Phase 1 — Foundation (no widget changes)

**Files: `app_theme.dart`, new `app_custom_colors.dart`, new `theme_cubit.dart`, `main.dart`, `style_card.dart`**

### 1A — `AppCustomColors` ThemeExtension

New file `lib/core/theme/app_custom_colors.dart`. Holds every color that has no standard `colorScheme` slot, with explicit light and dark values:

```dart
@immutable
class AppCustomColors extends ThemeExtension<AppCustomColors> {
  const AppCustomColors({
    required this.graphNodeSaved,
    required this.graphNodeOwn,
    required this.graphNodeDraft,
    required this.graphDotPattern,
    required this.graphEdge,
    required this.storageNotes,
    required this.storageModel,
    required this.storageChatHistory,
    required this.storageOther,
    required this.success,
    required this.onSuccess,
  });

  final Color graphNodeSaved;
  final Color graphNodeOwn;
  final Color graphNodeDraft;
  final Color graphDotPattern;
  final Color graphEdge;
  final Color storageNotes;
  final Color storageModel;
  final Color storageChatHistory;
  final Color storageOther;
  final Color success;
  final Color onSuccess;
  // Elevation / shadow tints introduced by the redesign — keep them in the
  // extension so dark mode can dial them down without re-discovering hex.
  final Color navShadow;
  final Color elevationMd;
  final Color shadowPrimary;

  static const light = AppCustomColors(
    graphNodeSaved:     Color(0xFF319BED),
    graphNodeOwn:       Color(0xFF059669),
    graphNodeDraft:     Color(0xFFD97706),
    graphDotPattern:    Color(0xFFE2E8F0),
    graphEdge:          Color(0xFFCBD5E1),
    storageNotes:       Color(0xFF319BED),
    storageModel:       Color(0xFF4CAF50),
    storageChatHistory: Color(0xFFFF9800),
    storageOther:       Color(0xFF9E9E9E),
    success:            Color(0xFF22C55E),
    onSuccess:          Color(0xFFFFFFFF),
    navShadow:          Color(0x24005AB6),
    elevationMd:        Color(0x1415181C),
    shadowPrimary:      Color(0x3D0075F2),
  );

  static const dark = AppCustomColors(
    graphNodeSaved:     Color(0xFF319BED),
    graphNodeOwn:       Color(0xFF34D399),
    graphNodeDraft:     Color(0xFFFBBF24),
    graphDotPattern:    Color(0xFF1E2230),
    graphEdge:          Color(0xFF334155),
    storageNotes:       Color(0xFF319BED),
    storageModel:       Color(0xFF66BB6A),
    storageChatHistory: Color(0xFFFFB74D),
    storageOther:       Color(0xFFBDBDBD),
    success:            Color(0xFF4ADE80),
    onSuccess:          Color(0xFF000000),
    // Dial shadows down ~50% in dark — large blue lifts read too strong
    // against a deep surface and cause the "halo" look.
    navShadow:          Color(0x1200334D),
    elevationMd:        Color(0x29000000),
    shadowPrimary:      Color(0x1F0075F2),
  );

  @override
  AppCustomColors copyWith({ ... }) => AppCustomColors( ... );

  @override
  AppCustomColors lerp(AppCustomColors? other, double t) => this;
}
```

### 1B — `AppTheme.dark` + attach extension to both themes

```dart
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    extensions: const [AppCustomColors.light],
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary:               Color(0xFF319BED),
      onPrimary:             Color(0xFFFFFFFF),
      primaryContainer:      Color(0xFF1A7EC8),
      onPrimaryContainer:    Color(0xFFFEFCFF),
      secondary:             Color(0xFF475F89),
      onSecondary:           Color(0xFFFFFFFF),
      secondaryContainer:    Color(0xFFB8CFFF),
      onSecondaryContainer:  Color(0xFF415882),
      tertiary:              Color(0xFF934700),
      onTertiary:            Color(0xFFFFFFFF),
      tertiaryContainer:     Color(0xFFB85A00),
      onTertiaryContainer:   Color(0xFFFFFBFF),
      error:                 Color(0xFFBA1A1A),
      onError:               Color(0xFFFFFFFF),
      errorContainer:        Color(0xFFFFDAD6),
      onErrorContainer:      Color(0xFF93000A),
      surface:               Color(0xFFFFFFFF),
      onSurface:             Color(0xFF191C1E),
      onSurfaceVariant:      Color(0xFF414753),
      outline:               Color(0xFF727785),
      outlineVariant:        Color(0xFFC1C6D5),
      inverseSurface:        Color(0xFF2E3132),
      onInverseSurface:      Color(0xFFF0F1F3),
      inversePrimary:        Color(0xFFABC7FF),
    ),
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    extensions: const [AppCustomColors.dark],
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary:               Color(0xFF319BED),
      onPrimary:             Color(0xFFFFFFFF),
      primaryContainer:      Color(0xFF1A5F9E),
      onPrimaryContainer:    Color(0xFFD6E8FF),
      secondary:             Color(0xFF8AABDC),
      onSecondary:           Color(0xFF0A1929),
      secondaryContainer:    Color(0xFF1E3A5F),
      onSecondaryContainer:  Color(0xFFB8CFFF),
      tertiary:              Color(0xFFFFB77C),
      onTertiary:            Color(0xFF4A1800),
      tertiaryContainer:     Color(0xFF6B2900),
      onTertiaryContainer:   Color(0xFFFFDBC7),
      error:                 Color(0xFFFF6B6B),
      onError:               Color(0xFF000000),
      errorContainer:        Color(0xFF93000A),
      onErrorContainer:      Color(0xFFFFDAD6),
      surface:               Color(0xFF0F1117),
      onSurface:             Color(0xFFE4E6EB),
      onSurfaceVariant:      Color(0xFFB0B8C8),
      outline:               Color(0xFF8A93A8),
      outlineVariant:        Color(0xFF3A3F52),
      inverseSurface:        Color(0xFFE4E6EB),
      onInverseSurface:      Color(0xFF0F1117),
      inversePrimary:        Color(0xFF1A5F9E),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A0C12),
  );
}
```

### 1C — `ThemeCubit` (`lib/settings/cubit/theme_cubit.dart`)

Holds `ThemeMode` (system / light / dark). Persists choice in `AppSettingsModel` (Isar).

### 1D — Wire up `main.dart`

```dart
MaterialApp(
  theme:     AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode, // from ThemeCubit
)
```

### 1E — `style_card.dart` calls `ThemeCubit`

The toggle UI already exists. Wire tap → `context.read<ThemeCubit>().setMode(...)`.

**After Phase 1:** Toggle works. Flutter built-in widgets (buttons, progress indicators, snackbars, ripples) go dark immediately. App's own widgets still show light — they still use `AppColors.*`. Phases 2–5 fix them.

---

## Phase 2 — Shared widgets (~5 files, highest leverage)

These are used on every screen — fixing them fixes the most UI at once.

For each file: replace `AppColors.xxx` → `Theme.of(context).colorScheme.xxx` or `Theme.of(context).extension<AppCustomColors>()!.xxx`.

| File | Replacements |
|---|---|
| `lib/common/widgets/floating_nav.dart` | surface → colorScheme, outlineVariant, primary, onSurfaceVariant + new redesigned glass-pill shadows `0x24005AB6` / `0x1415181C` / `0x3D0075F2` → `AppCustomColors.navShadow` / `elevationMd` / `shadowPrimary` |
| `lib/common/widgets/user_avatar.dart` | surface, primary, outline |
| `lib/common/widgets/note_card/note_card.dart` | surface, onSurface, onSurfaceVariant, primary, outline, outlineVariant + hardcoded `0xFF1E293B` → onSurface, `0xFFF1F5F9` → surfaceContainerHigh |
| `lib/common/widgets/note_card/large_note_card.dart` + `embedded_note_card.dart` + `reference_note_card.dart` + `dm_note_card.dart` + `dm_own_note_card.dart` | Same palette as `note_card.dart` |
| `lib/features/vishnu/widgets/feed_filter_chips.dart` | surface, primary, onSurfaceVariant |

---

## Phase 3 — Feature modules (one PR per sub-phase)

> **Path note:** the codebase moved every feature module under `lib/features/<feature>/`. Old `lib/<feature>/` paths in the original draft are no longer valid.

### 3A — Vishnu
- `lib/features/vishnu/pages/vishnu_feed_page.dart`
- `lib/features/vishnu/drawer/widgets/vishnu_drawer.dart` — `0xFF334155` → onSurfaceVariant, `0x1A6750A4` → primary.withValues(alpha:)

### 3B — Thread
- `lib/features/thread/pages/thread_page.dart`
- `lib/features/thread/widgets/` (thread_app_bar, thread_reply_composer, thread_segmented_toggle)

### 3C — Brahma
- `lib/features/brahma/graph/pages/graph_page.dart`
- `lib/features/brahma/graph/widgets/graph_header.dart` — graphNodeTypeColors → `custom.graphNodeSaved/Own/Draft`
- `lib/features/brahma/graph/widgets/graph_canvas.dart`
- `lib/features/brahma/graph/widgets/graph_node_panel.dart`
- `lib/features/brahma/graph/widgets/compose_action_bar.dart`
- `lib/features/brahma/graph/widgets/compose_header.dart`
- `lib/features/brahma/graph/painters/dot_pattern_painter.dart` — dot color → `custom.graphDotPattern`
- `lib/features/brahma/graph/painters/edge_painter.dart` — edge color → `custom.graphEdge`

### 3D — Shiv
- `lib/features/shiv/pages/shiv_page.dart`
- `lib/features/shiv/pages/shiv_home_page.dart` (new in redesign)
- `lib/features/shiv/chat/pages/shiv_chat_page.dart`
- `lib/features/shiv/chat/widgets/` (all widgets)
- `lib/features/shiv/chat/tree/widgets/branch_tree_graph.dart`
- `lib/features/shiv/composer_chat/` (cubit + widgets — new in redesign)
- `lib/features/shiv/gana/form/widgets/` + `gana/detail/pages/` (new in redesign — `gana_form_atoms.dart`, `gana_form_controls.dart`, `gana_form_sections.dart`, `gana_detail_page.dart`)
- `lib/features/shiv/nataraj/pages/` + `widgets/`
- `lib/features/shiv/model_select/pages/` + `widgets/` — `0xFF22C55E` → `custom.success`

### 3E — Settings
- `lib/features/settings/pages/settings_page.dart`
- `lib/features/settings/pages/edit_profile_page.dart` (rewrote in redesign — uses Newsreader display font, ambient backdrop, bottom-pinned CTA)
- `lib/features/settings/pages/blocked_users_page.dart`
- `lib/features/settings/widgets/settings_card.dart` — new shared `SettingsGroup` / `SettingsRow` / `SettingsRowDivider` atoms; migrate these once and every settings row picks it up. `SettingsRow.valueAccent` paints the trailing value in primary — keep the same `colorScheme.primary` swap (already used by `StorageMetricsRow` for the live total, and by `SettingsPickerButton` for sync-window / retention values)
- `lib/features/settings/widgets/storage_card.dart` — storage bar colors → `custom.storageModel/ChatHistory/Other`
- `lib/features/settings/widgets/` (ai_card, identity_card, style_card, profile_card, settings_buttons, section_label, media_row, cloud_provider_card, logout_button)

---

## Phase 4 — Onboarding (lowest priority — seen once)

- `lib/features/onboarding/pages/` (splash, welcome, how_it_works, about_you, your_identity_keys, import_identity)
- `lib/features/onboarding/widgets/` (key_card, generated_avatar, terms_checkbox, onboarding_app_bar, field_label, key_qr_scanner_page)

The redesign added an ambient blob backdrop on every onboarding screen (decorative radial gradients) — these read `AppColors.primary.withValues(alpha:)` today and should switch to `colorScheme.primary.withValues(alpha:)`.

`TermsCheckbox` is the App-Review gating control; its underlined link style needs both light and dark treatments (use `colorScheme.primary` instead of the inline `0x...` decoration colour).

---

## Phase 5 — Cleanup & delete `AppColors`

- All `AppColors.*` references are gone — delete `lib/core/theme/app_theme.dart` `AppColors` class entirely
- Replace any remaining `Colors.white` (13 usages) → `colorScheme.surface` or `colorScheme.onPrimary` by context
- Replace any remaining `Colors.black` (7 usages) → `colorScheme.onSurface` by context
- No raw `Color(0x...)` anywhere in widget files
- `flutter analyze` → 0 issues
- Visual QA: every screen in light and dark

---

## Mapping table — `AppColors` → theme

### Standard `colorScheme` slots

| `AppColors.xxx` | `Theme.of(context).colorScheme.xxx` |
|---|---|
| `primary` | `primary` |
| `primaryContainer` | `primaryContainer` |
| `onPrimary` | `onPrimary` |
| `onPrimaryContainer` | `onPrimaryContainer` |
| `secondary` | `secondary` |
| `secondaryContainer` | `secondaryContainer` |
| `onSecondaryContainer` | `onSecondaryContainer` |
| `error` | `error` |
| `onError` | `onError` |
| `errorContainer` | `errorContainer` |
| `onErrorContainer` | `onErrorContainer` |
| `surface` | `surface` |
| `onSurface` | `onSurface` |
| `onSurfaceVariant` | `onSurfaceVariant` |
| `surfaceContainerLowest` | `surfaceContainerLowest` |
| `surfaceContainerLow` | `surfaceContainerLow` |
| `surfaceContainer` | `surfaceContainer` |
| `surfaceContainerHigh` | `surfaceContainerHigh` |
| `surfaceContainerHighest` | `surfaceContainerHighest` |
| `outline` | `outline` |
| `outlineVariant` | `outlineVariant` |
| `inverseSurface` | `inverseSurface` |
| `inverseOnSurface` | `onInverseSurface` |
| `inversePrimary` | `inversePrimary` |

### `AppCustomColors` extension slots

| Hardcoded color | `Theme.of(context).extension<AppCustomColors>()!.xxx` |
|---|---|
| graph node saved `0xFF319BED` | `graphNodeSaved` |
| graph node own `0xFF059669` | `graphNodeOwn` |
| graph node draft `0xFFD97706` | `graphNodeDraft` |
| dot pattern bg | `graphDotPattern` |
| graph edges | `graphEdge` |
| storage bar: notes `0xFF319BED` | `storageNotes` |
| storage bar: model `0xFF4CAF50` | `storageModel` |
| storage bar: chat `0xFFFF9800` | `storageChatHistory` |
| storage bar: other `0xFF9E9E9E` | `storageOther` |
| success green `0xFF22C55E` | `success` |
| floating-nav blue lift `0x24005AB6` | `navShadow` |
| neutral elevation md `0x1415181C` | `elevationMd` |
| primary FAB elevation `0x3D0075F2` | `shadowPrimary` |
| ambient onboarding blob (primary @ ~0.07–0.10 alpha) | derived from `colorScheme.primary.withValues(alpha:)` — no extension slot needed |

---

## Current status

- [ ] Phase 1 — Foundation
- [ ] Phase 2 — Shared widgets
- [ ] Phase 3A — Vishnu
- [ ] Phase 3B — Thread
- [ ] Phase 3C — Brahma
- [ ] Phase 3D — Shiv
- [ ] Phase 3E — Settings
- [ ] Phase 4 — Onboarding
- [ ] Phase 5 — Cleanup + delete `AppColors`
