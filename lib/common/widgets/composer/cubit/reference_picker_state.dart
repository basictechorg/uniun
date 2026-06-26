part of 'reference_picker_cubit.dart';

enum ReferenceTab { all, saved, own, drafts }

class ReferencePickerState {
  const ReferencePickerState({
    this.tab = ReferenceTab.all,
    this.query = '',
    this.results = const [],
    this.profiles = const {},
    this.loading = false,
  });

  final ReferenceTab tab;
  final String query;

  /// Candidate references for the active tab + query.
  final List<ComposerReference> results;

  /// Author profiles keyed by pubkey, enriched lazily for the visible rows.
  final Map<String, ProfileEntity> profiles;
  final bool loading;

  ReferencePickerState copyWith({
    ReferenceTab? tab,
    String? query,
    List<ComposerReference>? results,
    Map<String, ProfileEntity>? profiles,
    bool? loading,
  }) {
    return ReferencePickerState(
      tab: tab ?? this.tab,
      query: query ?? this.query,
      results: results ?? this.results,
      profiles: profiles ?? this.profiles,
      loading: loading ?? this.loading,
    );
  }
}
