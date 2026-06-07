part of 'blocked_users_cubit.dart';

enum BlockedUsersStatus { initial, loading, loaded, error }

class BlockedUsersState {
  const BlockedUsersState({
    this.status = BlockedUsersStatus.initial,
    this.users = const [],
    this.errorMessage,
  });

  final BlockedUsersStatus status;
  final List<BlockedUserEntity> users;
  final String? errorMessage;

  BlockedUsersState copyWith({
    BlockedUsersStatus? status,
    List<BlockedUserEntity>? users,
    String? errorMessage,
  }) {
    return BlockedUsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
