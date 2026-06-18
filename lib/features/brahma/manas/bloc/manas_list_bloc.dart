import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';

part 'manas_list_event.dart';
part 'manas_list_state.dart';

@injectable
class ManasListBloc extends Bloc<ManasListEvent, ManasListState> {
  final GetManasListUseCase _getManasList;
  final DeleteManasUseCase _deleteManas;

  ManasListBloc(this._getManasList, this._deleteManas)
      : super(const ManasListState()) {
    on<ManasListLoadEvent>(_onLoad);
    on<ManasListDeleteEvent>(_onDelete);
  }

  Future<void> _onLoad(
      ManasListLoadEvent event, Emitter<ManasListState> emit) async {
    emit(state.copyWith(status: ManasListStatus.loading));
    final result = await _getManasList.call();
    result.fold(
      (f) => emit(state.copyWith(
          status: ManasListStatus.error, errorMessage: f.toMessage())),
      (list) => emit(state.copyWith(
          status: ManasListStatus.loaded, manases: list)),
    );
  }

  Future<void> _onDelete(
      ManasListDeleteEvent event, Emitter<ManasListState> emit) async {
    final r = await _deleteManas.call(event.manasId);
    r.fold((_) {}, (_) {});
    add(const ManasListLoadEvent());
  }
}
