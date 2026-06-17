part of 'manas_form_bloc.dart';

sealed class ManasFormEvent {
  const ManasFormEvent();
}

final class ManasFormLoadEvent extends ManasFormEvent {
  const ManasFormLoadEvent(this.manasId);
  final String? manasId;
}

final class ManasFormNameChangedEvent extends ManasFormEvent {
  const ManasFormNameChangedEvent(this.value);
  final String value;
}

final class ManasFormDescriptionChangedEvent extends ManasFormEvent {
  const ManasFormDescriptionChangedEvent(this.value);
  final String value;
}

/// Fired when the user picks an icon from the grid — pins the choice so
/// subsequent name keystrokes don't re-suggest over it.
final class ManasFormIconPickedEvent extends ManasFormEvent {
  const ManasFormIconPickedEvent(this.iconName);
  final String iconName;
}

/// Fired when the user picks 1–3 colours (or clears them) from the swatch
/// grid. Empty list = collapse back to the default saved-blue.
final class ManasFormColorsPickedEvent extends ManasFormEvent {
  const ManasFormColorsPickedEvent(this.colorHexes);
  final List<String> colorHexes;
}

final class ManasFormSearchEvent extends ManasFormEvent {
  const ManasFormSearchEvent(this.query);
  final String query;
}

final class ManasFormToggleMembershipEvent extends ManasFormEvent {
  const ManasFormToggleMembershipEvent(this.preview);
  final ManasNotePreview preview;
}

final class ManasFormSubmitEvent extends ManasFormEvent {
  const ManasFormSubmitEvent();
}

final class ManasFormDeleteEvent extends ManasFormEvent {
  const ManasFormDeleteEvent();
}
