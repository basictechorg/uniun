# Manas — Brahma's User-Curated Sub-Experts

> **Status**: shipped (Phase 1).
> **Lives in**: Brahma (the knowledge-graph workspace).
> **Companion**: `docs/SHIVA/Ganas.md` (Phase 2 — AI agents that consume Manases).

A **Manas** ("मनस्" — mind / intellect / inner instrument in Sanskrit) is a user-curated, named subset of the user's notes that acts as a focused sub-expert. Brahma's graph view scopes to a single Manas when the user picks one from the drawer; otherwise it shows the full unscoped graph.

Think: tags, but explicit, ordered, and addressable by id — not implicit string buckets.

---

## 1. Functional model

### 1.1 What's in a Manas?

| Field | Notes |
|---|---|
| `name` | required, ≤60 chars |
| `description` | optional, multi-line |
| `iconName` | Material icon key. Auto-suggested from name keywords; user can override |
| Members | one or more **notes** — saved notes, the user's own published notes, or local drafts. Mixed-source allowed. |
| `createdAt`, `updatedAt` | metadata |

### 1.2 What a Manas is NOT

- **Not a Nostr event.** Manases are local-only config. Two devices belonging to the same user have independent Manas sets until/unless a private-config sync layer is added.
- **Not a tag.** A note can belong to N Manases simultaneously; membership is via an explicit link table, not by string matching.
- **Not a folder.** Adding a note to a Manas doesn't move it; the note still lives in saved-notes / own / drafts as before. Membership is a pointer.

### 1.3 User flow

```
Brahma tab
  ├─ Tap top-left logo OR edge-swipe ──► BrahmaDrawer opens
  │
  ├─ BrahmaDrawer
  │   ├─ "Brahma" entry ──► full unscoped graph (default)
  │   ├─ Manas tile (Rust Expert, 12 notes)  ──► tap: graph scopes to Manas
  │   │                                        ──► long-press: Edit / Delete sheet
  │   ├─ Manas tile (Life Lessons, 47 notes)
  │   └─ "+ New Manas" ──► ManasFormPage (create mode)
  │
  └─ Graph header (when scoped)
      ├─ Manas name + icon
      └─ ✏ ──► ManasFormPage (edit mode)
```

When scoped, the graph filters its node set to the Manas's membership. Reference edges that fall outside the membership are dropped naturally (the adjacency builder ignores refs to non-member ids). Same force-directed physics as the unscoped view — no extra layout logic.

---

## 2. Architecture

### 2.1 Layer overview

```
Presentation (BLoC + Pages + Widgets)
        │
        ▼  use cases only — never direct Isar
Domain (Entities + Repository interface + Use cases)
        │
        ▼  @Injectable(as: ManasRepository)
Data (Isar models + Repository impl)
        │
        ▼  isar.writeTxn
Isar (ManasModel + ManasNoteLinkModel — local DB)
```

### 2.2 Data model (Isar)

Two collections, **decoupled via a link table** so a note can belong to multiple Manases:

```
┌────────────────────────────┐        ┌────────────────────────────┐
│ ManasModel                 │        │ ManasNoteLinkModel         │
├────────────────────────────┤        ├────────────────────────────┤
│ Id  id      (autoincrement)│        │ Id   id    (autoincrement) │
│ String manasId   (uniq)    │ ◄──┐   │ String manasId             │
│ String name                │    │   │ String noteId              │
│ String? description        │    │   │ DateTime addedAt           │
│ String? iconName           │    │   │                            │
│ DateTime createdAt         │    │   │ @Index(composite:[noteId], │
│ DateTime updatedAt         │    │   │        unique: true)       │
└────────────────────────────┘    │   │ @Index() noteId            │
                                  │   └────────────────────────────┘
                                  │
       references manasId by hand │                  reverse lookup
       (no foreign-key constraint)│                  ("which Manases is
                                  │                   note X in?")
                                  │
                       Many-to-many link
```

**`noteId` is a free-form string**, intentionally. It holds:
- a 64-hex Nostr event id (for saved or own notes), OR
- a UUID `draftId` (for drafts).

There is no length validation — draft UUIDs and event hex never collide because the alphabets differ. The resolver layer (consumer code) decides what to look up.

### 2.3 The composite index — why

```dart
@Index(composite: [CompositeIndex('noteId')], unique: true)
late String manasId;
```

- **Composite + unique** prevents `(manasId, noteId)` duplicates: re-adding a note to the same Manas is a silent no-op, not an error.
- Standalone `@Index() noteId` enables the reverse lookup `"which Manases does note X belong to?"` — used when a user unsaves a note (the unsave dialog warns about Manas memberships) and by future Gana retrieval (see `docs/SHIVA/Ganas.md`).

### 2.4 Domain layer

```
lib/domain/
├── entities/manas/manas_entity.dart        ManasEntity (freezed)
├── repositories/manas_repository.dart       abstract ManasRepository
└── usecases/manas_usecases.dart             8 @lazySingleton use cases
                                             grouped in one file (SRP at
                                             class level, not file level)
```

```dart
abstract class ManasRepository {
  Future<Either<Failure, ManasEntity>> upsertManas(ManasEntity m);
  Future<Either<Failure, List<ManasEntity>>> getManasList();
  Future<Either<Failure, ManasEntity>> getManasById(String manasId);
  Future<Either<Failure, Unit>> deleteManas(String manasId);

  // Membership — idempotent on both sides
  Future<Either<Failure, Unit>> addNoteToManas(String manasId, String noteId);
  Future<Either<Failure, Unit>> removeNoteFromManas(String manasId, String noteId);
  Future<Either<Failure, List<String>>> getNoteIdsForManas(String manasId);
  Future<Either<Failure, List<String>>> getManasIdsForNote(String noteId);
}
```

`noteCount` on the entity is derived at read time by counting link rows — never stored on `ManasModel` (single source of truth).

### 2.5 Data layer

```
lib/data/
├── models/
│   ├── manas_model.dart            ManasModel + toDomain() ext
│   └── manas_note_link_model.dart  ManasNoteLinkModel
├── datasources/
│   └── isar_schemas.dart           Both schemas registered
└── repositories/
    └── manas_repository_impl.dart  @Injectable(as: ManasRepository)
                                    Every write wrapped in isar.writeTxn
                                    deleteManas: row + all links in one txn
```

### 2.6 Presentation layer

```
lib/features/brahma/manas/
├── bloc/
│   ├── manas_list_bloc.dart       backs the BrahmaDrawer
│   ├── manas_list_event.dart
│   ├── manas_list_state.dart
│   ├── manas_form_bloc.dart       create + edit (same bloc, both modes)
│   ├── manas_form_event.dart
│   └── manas_form_state.dart
├── pages/
│   └── manas_form_page.dart       full-screen create/edit form
└── widgets/
    ├── brahma_drawer.dart         the side drawer hosting the Manas list
    ├── manas_icon_picker.dart     bottom-sheet icon grid
    └── manas_membership_sheet.dart bottom sheet that adds a note to N Manases
```

Plus utilities shared with Brahma:

```
lib/features/brahma/utils/
├── brahma_scaffold_key.dart       GlobalKey<ScaffoldState> for openDrawer
├── manas_icons.dart               40-entry icon registry + keyword→icon map
└── manas_colors.dart              palette helpers (legacy — unused in v1)
```

### 2.7 Form behaviour

```
ManasFormBloc
  ├─ on load: caches a unified search pool
  │     ─ GetAllSavedNotesUseCase  ◄─ saved
  │     ─ GetOwnNotesUseCase       ◄─ own (authored)
  │     ─ GetDraftsUseCase         ◄─ local drafts
  │     ─ deduped by id
  │
  ├─ search keystrokes
  │   ─ debounced via .restartable() event transformer
  │   ─ filtered in-memory against the cached pool (no DB per keystroke)
  │   ─ each result row shows a provenance badge: Saved / Own / Draft
  │
  ├─ icon
  │   ─ auto-suggested via ManasIcons.suggestFromName(name)
  │   ─ overridable via manas_icon_picker
  │   ─ name edits keep updating the suggestion UNLESS the user explicitly picked one
  │
  └─ on submit:
       1. upsert ManasModel (gets manasId if new)
       2. diff pendingMembership against persistedMembership
       3. emit minimal addNoteToManas / removeNoteFromManas calls
       4. pop with `true` to trigger drawer reload
```

---

## 3. Graph integration

`GraphBloc.LoadGraphEvent` takes an optional `manasId`. When non-null:

```
1. Load saved + own + draft nodes as for the full graph
2. Fetch the Manas's link set via GetNoteIdsForManasUseCase
3. Filter `allNodes` to ids in the link set
4. Build adjacency over the filtered set
   (refs to non-members are dropped automatically — same guard as before)
5. Emit state.copyWith(nodes: ..., adjacency: ..., scopedManasId: ...)
```

The canvas is unchanged — same physics, same size function, same colour table. Only the node list shrinks. The header shows the Manas name + icon + edit pencil instead of the default "Brahma" label.

```
Full graph                       Scoped to "Rust Expert"
─────────────                    ────────────────────────
●─●─●                                  ●
│ │ │           ──►                   ╱│╲
●─●─●─●                              ● ● ●
   │                                  │
●─●─●                                 ●
(everything user owns/saved)     (only Manas members + edges
                                  between them)
```

---

## 4. Routes + l10n

- `AppRoutes.brahmaManasForm = 'brahmaManasForm'` (path `/brahma/manas/form`, optional `manasId` in extras).
- All UI strings in `lib/l10n/app_en.arb` under keys prefixed `manasForm*`, `manasDrawer*`, `manasMembershipSheet*`, `manasIconPickerTitle`, `graphHeaderManas*`, `noteCardAddToManas`, `unsaveManas*`. Zero hardcoded English.

---

## 5. Membership management from a note card

The note card's overflow menu has an **"Add to Manas"** item (gated on `isSaved == true` — only saved notes can be added to a Manas; if not saved, the user is prompted to save first via `noteCardManasSaveFailed`).

Tapping it opens `manas_membership_sheet.dart` — a bottom sheet listing all Manases with a checkmark on each one this note already belongs to:

```
┌──────────────────────────────┐
│  Add to Manas         ✕      │
├──────────────────────────────┤
│  🧠 Rust Expert       ✓      │ ◄ already a member; tap removes
│  🧠 Life Lessons             │ ◄ tap adds
│  🧠 Health Notes      ✓      │
│  ...                         │
│  ─────────────               │
│  + New Manas                 │ ◄ opens form, returns to sheet
└──────────────────────────────┘
```

Each toggle issues one `addNoteToManas` or `removeNoteFromManas` call and refreshes the per-Manas count in the same sheet (so the "12 notes" subtitle updates without closing).

---

## 6. Unsave guard

When a user unsaves a note that belongs to ≥1 Manas, the standard unsave confirmation expands to list the affected Manases:

```
┌────────────────────────────────────┐
│  Unsave note?                       │
├────────────────────────────────────┤
│  Unsaving this note will also       │
│  remove it from:                    │
│    • Rust Expert                    │
│    • Health Notes                   │
│                                    │
│  [ Cancel ]    [ Unsave anyway ]   │
└────────────────────────────────────┘
```

Reverse-lookup is `GetManasIdsForNoteUseCase` → list of `manasId` → fetch names. Uses the standalone `@Index() noteId` on the link table — single indexed query.

---

## 7. Cross-references

- **Ganas consume Manases.** When a Gana fires, it merges the union of its selected Manases' note ids and packs the content as the LLM's KNOWLEDGE block. See `docs/SHIVA/Ganas.md` §3 (Manas Context Loader) and §6 (Run lifecycle).
- **Notes have no Manas knowledge.** The note card doesn't know which Manases it belongs to until the membership sheet opens — kept that way deliberately so feed rendering doesn't pay a per-note query cost.

---

## 8. Folder structure summary

```
lib/
├── data/
│   ├── datasources/isar_schemas.dart                  ManasModelSchema +
│   │                                                  ManasNoteLinkModelSchema
│   ├── models/
│   │   ├── manas_model.dart                           Isar collection
│   │   └── manas_note_link_model.dart                 link/junction
│   └── repositories/
│       └── manas_repository_impl.dart                 @Injectable
│
├── domain/
│   ├── entities/manas/manas_entity.dart               freezed
│   ├── repositories/manas_repository.dart             interface
│   └── usecases/manas_usecases.dart                   8 use cases
│
├── features/brahma/manas/
│   ├── bloc/                                          list + form blocs
│   ├── pages/manas_form_page.dart                     create/edit page
│   └── widgets/
│       ├── brahma_drawer.dart                         drawer host
│       ├── manas_icon_picker.dart                     icon sheet
│       └── manas_membership_sheet.dart                add-to-Manas sheet
│
├── features/brahma/utils/
│   ├── brahma_scaffold_key.dart                       drawer key
│   └── manas_icons.dart                               icon registry + keyword map
│
├── core/router/
│   ├── app_routes.dart                                brahmaManasForm constant
│   └── app_router.dart                                /brahma/manas/form route
│
└── l10n/app_en.arb                                    manas* keys
```
