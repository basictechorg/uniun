/// What surface a Gana reads as input. `null` on the Gana row means a
/// standalone Gana that has no input — interval-only.
///
/// Stored on `GanaModel` via `@Enumerated(EnumType.name)` so the on-disk
/// value is the enum name (forward-compat with adding cases at the tail).
enum GanaInputType {
  group,
  privateGroup,
  dm,
  user,
  followedNote,
}
