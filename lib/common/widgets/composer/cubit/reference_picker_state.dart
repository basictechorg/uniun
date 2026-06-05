part of 'reference_picker_cubit.dart';

enum ReferenceTab { all, saved }

class ReferencePickerState {
  const ReferencePickerState({
    this.tab = ReferenceTab.all,
    this.query = '',
    this.results = const [],
    this.loading = false,
  });

  final ReferenceTab tab;
  final String query;

  /// Candidate references for the active tab + query.
  final List<ComposerReference> results;
  final bool loading;

  ReferencePickerState copyWith({
    ReferenceTab? tab,
    String? query,
    List<ComposerReference>? results,
    bool? loading,
  }) {
    return ReferencePickerState(
      tab: tab ?? this.tab,
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
    );
  }
}
