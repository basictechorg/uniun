# Isar DB - Complete Guide for Flutter

---

## What Is Isar DB?

Isar Database is a **local NoSQL database for Flutter and Dart**.

It is:
- Fast
- Offline-first
- Built specifically for Flutter
- Works on Android, iOS, macOS, Windows, Linux
- Written in native code (very performant)

Think of it like:

| Platform       | Equivalent |
| -------------- | ---------- |
| Web            | IndexedDB  |
| React Native   | Realm      |
| Native Android | Room       |
| Native iOS     | CoreData   |
| Flutter        | **Isar**   |

---

## Why Use Isar?

You use Isar when you want:
- Offline storage
- Caching API responses
- Storing user sessions
- Saving chat messages locally
- Fast search queries

It runs **on device**, not on a server.

---

## Isar vs SQLite

| Feature     | SQLite         | Isar                      |
| ----------- | -------------- | ------------------------- |
| Style       | Table-based    | Object-based (NoSQL)      |
| Queries     | SQL            | Dart query builder        |
| Speed       | Fast           | Faster for Flutter apps   |
| Integration | Manual mapping | Direct with Dart classes  |

If you hate writing SQL → you'll like Isar.

---

## How Isar Works (Simple Idea)

### Step 1: Define a Dart class

```dart
import 'package:isar/isar.dart';

part 'user.g.dart';

@collection
class User {
  Id id = Isar.autoIncrement;

  late String name;
  late int age;
}
```

### Step 2: Open the database

```dart
final isar = await Isar.open([UserSchema]);
```

### Step 3: Save data

```dart
await isar.writeTxn(() async {
  await isar.users.put(User()
    ..name = "Sam"
    ..age = 21);
});
```

### Step 4: Query data

```dart
final users = await isar.users.where().findAll();
```

No SQL. Just Dart classes.

---

## Important Concepts

### @collection
Marks a class as a database table/collection.

### Id
Primary key - uniquely identifies each record.

### writeTxn()
Every write (create/update/delete) must be inside a transaction.

### Query Builder
Instead of SQL, use Dart methods:
```dart
// Find all users named "Sam"
isar.users.filter().nameEqualTo("Sam").findAll();

// Find users older than 18
isar.users.filter().ageGreaterThan(18).findAll();
```

---

## How Isar Is Used in Uniun

In this project, Isar is used as a **local cache** in the Data Layer:

```
API Response (Remote)
       ↓
RemoteDataSource fetches data
       ↓
LocalDataSource saves to Isar DB   ← HERE
       ↓
Next time app opens → Load from Isar (offline support)
```

**Key file:** `lib/data/datasources/local_datasource.dart`

This means:
- If you search for "python" once, results are stored locally
- If you go offline, app can still show previous results
- App feels faster because data loads from device instead of API

---

## Isar vs Hive

| Feature    | Hive        | Isar              |
| ---------- | ----------- | ----------------- |
| Style      | Key-value   | Object-based      |
| Queries    | Basic       | Advanced filtering|
| Speed      | Fast        | Faster            |
| Scale      | Lightweight | More scalable     |

For serious apps → Isar is better.

---

## Isar vs Server Database

**Important:**

Isar = **local database only** (on device)

It does NOT replace:
- PostgreSQL
- MongoDB
- Any server storage

It runs only inside the app on the user's phone.

---

## Architecture With Isar in Uniun

```
User taps search
       ↓
SearchBloc (Presentation Layer)
       ↓
SearchUseCase (Domain Layer)
       ↓
SearchRepositoryImpl (Data Layer)
       ↓
  ┌────────────────┐
  │ RemoteDataSource│  ← Calls API (online)
  └────────┬───────┘
           ↓
  ┌────────────────┐
  │ LocalDataSource │  ← Saves to Isar (offline cache)
  └────────────────┘
```

---

## Performance

Isar is:
- Written in Rust (super fast native code)
- Zero-copy reads
- Reactive queries (auto-update UI when data changes)
- Cross-platform

---

## Final Simple Definition

> **Isar DB = A fast local database for Flutter that stores Dart objects directly on device.**

Used for: Offline apps, chat apps, caching, local persistence.
