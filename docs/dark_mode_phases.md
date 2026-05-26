# Dark Mode — Phased Rollout Plan

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

## Phase 2 — Shared widgets (~4 files, highest leverage)

These are used on every screen — fixing them fixes the most UI at once.

For each file: replace `AppColors.xxx` → `Theme.of(context).colorScheme.xxx` or `Theme.of(context).extension<AppCustomColors>()!.xxx`.

| File | Replacements |
|---|---|
| `lib/common/widgets/floating_nav.dart` | surface → colorScheme, outlineVariant, primary, onSurfaceVariant |
| `lib/common/widgets/user_avatar.dart` | surface, primary, outline |
| `lib/vishnu/widgets/note_card.dart` | surface, onSurface, onSurfaceVariant, primary, outline, outlineVariant + hardcoded `0xFF1E293B` → onSurface, `0xFFF1F5F9` → surfaceContainerHigh |
| `lib/vishnu/widgets/feed_filter_chips.dart` | surface, primary, onSurfaceVariant |

---

## Phase 3 — Feature modules (one PR per sub-phase)

### 3A — Vishnu
- `lib/vishnu/pages/vishnu_feed_page.dart`
- `lib/vishnu/drawer/widgets/vishnu_drawer.dart` — `0xFF334155` → onSurfaceVariant, `0x1A6750A4` → primary.withValues(alpha:)

### 3B — Thread
- `lib/thread/pages/thread_page.dart`
- `lib/thread/widgets/` (thread_app_bar, thread_reply_composer, thread_segmented_toggle)

### 3C — Brahma
- `lib/brahma/graph/pages/graph_page.dart`
- `lib/brahma/graph/widgets/graph_header.dart` — graphNodeTypeColors → `custom.graphNodeSaved/Own/Draft`
- `lib/brahma/graph/widgets/graph_canvas.dart`
- `lib/brahma/graph/widgets/graph_node_panel.dart`
- `lib/brahma/graph/widgets/compose_action_bar.dart`
- `lib/brahma/graph/widgets/compose_header.dart`
- `lib/brahma/graph/painters/dot_pattern_painter.dart` — dot color → `custom.graphDotPattern`
- `lib/brahma/graph/painters/edge_painter.dart` — edge color → `custom.graphEdge`

### 3D — Shiv
- `lib/shiv/pages/shiv_page.dart`
- `lib/shiv/chat/pages/shiv_chat_page.dart`
- `lib/shiv/chat/widgets/` (all widgets)
- `lib/shiv/chat/tree/widgets/branch_tree_graph.dart`
- `lib/shiv/model_select/pages/` + `widgets/` — `0xFF22C55E` → `custom.success`

### 3E — Settings
- `lib/settings/pages/settings_page.dart`
- `lib/settings/widgets/storage_card.dart` — storage bar colors → `custom.storageModel/ChatHistory/Other`
- `lib/settings/widgets/` (ai_card, identity_card, style_card, profile_card, settings_buttons)

---

## Phase 4 — Onboarding (lowest priority — seen once)

- `lib/onboarding/pages/` (splash, welcome, about_you, identity_keys, import_identity)
- `lib/onboarding/widgets/` (key_card, generated_avatar)

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
