# Domain Layer - Complete Guide

`lib/domain/`

---

## What Is the Domain Layer?

**Job:** Define business rules (WHAT should happen — not HOW)

It is the **middle layer** between:
- Presentation Layer (UI/BLoC) — above it
- Data Layer (API/Database) — below it

The Domain Layer does NOT know:
- How data is fetched from API
- How data is saved to database
- Anything about Flutter UI

It only defines:
- What data looks like (Entities)
- What operations exist (UseCases)
- What interfaces must be implemented (Repositories)
- What parameters operations need (Inputs)

---

## Folder Structure

```
lib/domain/
├── entities/        # Clean domain objects
├── usecases/        # Business logic operations
├── repositories/    # Abstract interfaces
└── inputs/          # Parameters for use cases
```

---

## 1. Inputs (`lib/domain/inputs/`)

### What Are Inputs?

Inputs are **read-only parameter containers**. They just hold data to pass to a UseCase cleanly.

They do:
- Group related parameters into one typed object

They do NOT do:
- Validation
- Logic
- Checking

### Simple Analogy

Without Input class:
```dart
// Messy — 5 separate arguments
useCase.joinCommunity(communityID, userID, token, timestamp, ...);
```

With Input class:
```dart
// Clean — one object carries everything
useCase.joinCommunity(JoinCommunityInput(communityID: 5));
```

### Real Examples From Codebase

```dart
// lib/domain/inputs/community_input.dart

// Just holds communityID — nothing else
@freezed
class JoinCommunityInput with _$JoinCommunityInput {
  const factory JoinCommunityInput({
    required int communityID,
  }) = _JoinCommunityInput;
}

// Bundles 3 related params into one object
@freezed
class GetCommunityFeedInput with _$GetCommunityFeedInput {
  const factory GetCommunityFeedInput({
    required int communityID,
    required OrderBy orderBy,    // new/top/hot
    required SortBy sortOrder,   // asc or desc
  }) = _GetCommunityFeedInput;
}

// Login needs email + password together
@freezed
class LoginUserInput with _$LoginUserInput {
  const factory LoginUserInput({
    required String password,
    required String email,
  }) = _LoginUserInput;
}
```

### Why `@freezed` on Inputs?

Freezed makes them **immutable** — once created, values cannot be changed accidentally:

```dart
final input = JoinCommunityInput(communityID: 5);
// input.communityID = 10;  ❌ ERROR — cannot change!
```

### How Inputs Flow

```
BLoC creates input:
  GetCommunityFeedInput(
    communityID: 5,
    orderBy: OrderBy.new,
    sortOrder: SortBy.desc
  )
       ↓
UseCase receives this one object
       ↓
Repository uses: input.communityID, input.orderBy, input.sortOrder
```

---

<!-- More sections coming soon -->
