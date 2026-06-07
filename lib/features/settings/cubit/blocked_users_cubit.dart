import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';
import 'package:uniun/domain/usecases/blocked_user_usecases.dart';

part 'blocked_users_state.dart';

class BlockedUsersCubit extends Cubit<BlockedUsersState> {
  BlockedUsersCubit() : super(const BlockedUsersState());

  Future<void> load() async {
    emit(state.copyWith(status: BlockedUsersStatus.loading));
    final result = await getIt<GetBlockedUsersUseCase>().call();
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(
        status: BlockedUsersStatus.error,
        errorMessage: f.toMessage(),
      )),
      (users) => emit(state.copyWith(
        status: BlockedUsersStatus.loaded,
        users: users,
      )),
    );
  }

  Future<void> unblock(String pubkeyHex) async {
    final result = await getIt<UnblockUserUseCase>().call(pubkeyHex);
    if (isClosed) return;
    result.fold((_) {}, (_) => load());
  }
}
