# Welcome Screen Redesign — Design

**Date:** 2026-06-17
**Scope:** `lib/features/onboarding/pages/welcome_page.dart` + `lib/l10n/app_en.arb`
**Status:** Approved (visual mockup signed off via brainstorming companion)

## Problem

The current welcome screen reads as unfinished: the top third is dead space, every
element is the same brand blue on white (no hierarchy), the `left · right` dot-aligned
tagline layout is visually awkward, and the screen carries none of the app's identity
(the Trimurti concept or the "knowledge graph" product).

## Direction

**Refined minimal** — keep the existing white + brand-blue language, but fix proportions,
add depth and hierarchy, and give the tagline real meaning. Approved direction "A" with two
borrowed elements: the Trimurti pillar row and a "second brain" tagline.

## Final layout (top → bottom, vertically centered, content anchored with flexible spacers)

1. **Soft radial blue glow** behind the logo (decorative, low-opacity `primary` radial).
2. **Logo** — existing `assets/images/uniun-logo.svg`, ~64px.
3. **Wordmark** "UNIUN" — heavy weight, tight tracking, rendered with a blue gradient
   (`primary → primaryContainer`) via `ShaderMask`.
4. **Subtitle** — "Your decentralized **second brain**". "Your decentralized " is muted
   (`onSurfaceVariant`); "second brain" is bold and brand-blue.
5. **Trimurti pillar row** — one bordered, rounded, faint-blue-tinted container split into
   **three equal-width columns** with thin dividers. Each column: a blue accent dot, the
   deity name (bold, ink), and the role (uppercase, blue, letter-spaced):
   - Brahma · CREATE
   - Vishnu · REFLECT
   - Shiv · TRANSFORM
6. **Primary button** — "Create Your Avatar", full-width gradient blue
   (`primary → lighter`), white `Icons.add_rounded`, soft drop shadow. Same action as
   today (generate keypair → `aboutYou` route).
7. **Secondary button** — "Restore Your Avatar", white ghost with subtle border, brand-blue
   `Icons.vpn_key_rounded`. Same action (→ `importIdentity`).
8. **Learn link** — "Learn how UNIUN works →" (unchanged).

Both button icons are matched Material glyphs (same size/weight) — no emoji.

## Strings (l10n — all new text via `AppLocalizations`)

- `welcomeSubtitleLead` = "Your decentralized "
- `welcomeSubtitleEmphasis` = "second brain"
- `welcomePillarBrahma` / `welcomePillarVishnu` / `welcomePillarShiv` = deity names
- `welcomeRoleCreate` / `welcomeRoleReflect` / `welcomeRoleTransform` = roles
- Reuse: `welcomeCreateIdentity`, `welcomeImportKey`, `welcomeLearnHow`
- `welcomeTagline` becomes unused (left in place; the old dot-grid tagline helpers are removed).

## Out of scope

No route/flow changes, no new pages, no theme-color changes (existing `AppColors`), no
dark mode work, no wiring of the "Learn how" link (still a TODO, as today). Entrance
animation optional/minor — not required for sign-off.
