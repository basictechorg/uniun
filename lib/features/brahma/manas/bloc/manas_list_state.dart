part of 'manas_list_bloc.dart';

enum ManasListStatus { initial, loading, loaded, error }

class ManasListState {
  const ManasListState({
    this.status = ManasListStatus.initial,
    this.manases = const [],
    this.errorMessage,
  });

  final ManasListStatus status;
  final List<ManasEntity> manases;
  final String? errorMessage;

  ManasListState copyWith({
    ManasListStatus? status,
    List<ManasEntity>? manases,
    String? errorMessage,
  }) {
    return ManasListState(
      status: status ?? this.status,
      manases: manases ?? this.manases,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
