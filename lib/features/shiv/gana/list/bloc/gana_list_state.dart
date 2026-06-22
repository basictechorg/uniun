part of 'gana_list_bloc.dart';

enum GanaListStatus { initial, loading, ready, error }

class GanaListState {
  const GanaListState({
    this.status = GanaListStatus.initial,
    this.ganas = const [],
    this.lastRuns = const {},
    this.errorMessage,
  });

  final GanaListStatus status;
  final List<GanaEntity> ganas;
  final Map<String, GanaRunEntity?> lastRuns;
  final String? errorMessage;

  GanaListState copyWith({
    GanaListStatus? status,
    List<GanaEntity>? ganas,
    Map<String, GanaRunEntity?>? lastRuns,
    String? errorMessage,
  }) =>
      GanaListState(
        status: status ?? this.status,
        ganas: ganas ?? this.ganas,
        lastRuns: lastRuns ?? this.lastRuns,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
