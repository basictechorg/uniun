/// FNV-1a 64-bit hash of [string]. Used to derive a deterministic Isar `Id` from
/// a natural string key (Isar primary keys must be `int`, so a stable string key
/// is hashed to an int). The same string yields the same id on every device,
/// which is what makes such rows safe to reconcile across devices by their
/// natural key. Collision probability across realistic key counts is negligible.
///
/// ## Caveats — read before reusing this elsewhere
/// - **Native/VM only.** This relies on 64-bit integer wraparound. On the web
///   (dart2js/Wasm) a Dart `int` is a 53-bit double, so the multiplications
///   overflow to a *different* value and the derived ids would diverge from
///   mobile. UNIUN runs the mesh only on native (Android/Apple), so it is safe
///   here — do not move it into web-shared code.
/// - **Non-standard FNV-1a variant.** It folds each UTF-16 code unit as two
///   bytes (`>> 8` then `& 0xFF`) rather than hashing the UTF-8 encoding, so it
///   is NOT interoperable with a textbook FNV-1a. Every device must run *this
///   exact* function or the same key hashes to a different id and cross-device
///   reconciliation breaks. Treat the algorithm as frozen.
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
