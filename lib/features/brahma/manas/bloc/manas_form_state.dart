part of 'manas_form_bloc.dart';

enum ManasFormStatus { initial, loading, ready, saving, saved, deleted, error }

enum ManasNoteKind { saved, own, draft, unknown }

class ManasNotePreview {
  const ManasNotePreview({
    required this.noteId,
    required this.preview,
    required this.kind,
  });

  final String noteId;
  final String preview;
  final ManasNoteKind kind;
}

class ManasFormState {
  const ManasFormState({
    this.status = ManasFormStatus.initial,
    this.manasId,
    this.isEditMode = false,
    this.name = '',
    this.description = '',
    this.iconName,
    this.iconUserPicked = false,
    this.colorHexes = const <String>[],
    this.persistedMembership = const {},
    this.pendingMembership = const {},
    this.membershipPreviews = const {},
    this.searchQuery = '',
    this.searchResults = const [],
    this.searching = false,
    this.errorMessage,
    this.createdAt,
  });

  final ManasFormStatus status;
  final String? manasId;

  /// True when this form was opened with an existing `manasId` (edit flow).
  /// Drives the "Delete" button + the appbar title variant.
  final bool isEditMode;

  final String name;
  final String description;

  /// Currently-resolved icon name (a key into `ManasIcons.all`), or null
  /// when no keyword matches and the user hasn't picked one.
  final String? iconName;

  /// True once the user has explicitly picked an icon from the grid. When
  /// false, the form re-runs auto-suggest on every name keystroke. Form-
  /// local — not persisted; the DB only stores [iconName].
  final bool iconUserPicked;

  /// User-chosen 1–3 hex colours for nodes when scoped to this Manas.
  /// Empty = the graph keeps the default saved-blue.
  final List<String> colorHexes;

  /// Note ids that are currently persisted as links for this Manas.
  final Set<String> persistedMembership;

  /// Pending membership while user edits — diffed against [persistedMembership]
  /// on save to emit the minimal add/remove calls.
  final Set<String> pendingMembership;

  /// Resolved preview rows keyed by noteId — shown as chips for current
  /// membership and used to render search results.
  final Map<String, ManasNotePreview> membershipPreviews;

  final String searchQuery;
  final List<ManasNotePreview> searchResults;
  final bool searching;

  final String? errorMessage;
  final DateTime? createdAt;

  bool get canSave =>
      name.trim().isNotEmpty &&
      status != ManasFormStatus.saving &&
      status != ManasFormStatus.loading;

  ManasFormState copyWith({
    ManasFormStatus? status,
    String? manasId,
    bool? isEditMode,
    String? name,
    String? description,
    String? iconName,
    bool? iconUserPicked,
    List<String>? colorHexes,
    Set<String>? persistedMembership,
    Set<String>? pendingMembership,
    Map<String, ManasNotePreview>? membershipPreviews,
    String? searchQuery,
    List<ManasNotePreview>? searchResults,
    bool? searching,
    String? errorMessage,
    DateTime? createdAt,
    bool clearError = false,
    bool clearIcon = false,
  }) {
    return ManasFormState(
      status: status ?? this.status,
      manasId: manasId ?? this.manasId,
      isEditMode: isEditMode ?? this.isEditMode,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: clearIcon ? null : (iconName ?? this.iconName),
      iconUserPicked: iconUserPicked ?? this.iconUserPicked,
      colorHexes: colorHexes ?? this.colorHexes,
      persistedMembership: persistedMembership ?? this.persistedMembership,
      pendingMembership: pendingMembership ?? this.pendingMembership,
      membershipPreviews: membershipPreviews ?? this.membershipPreviews,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      searching: searching ?? this.searching,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
