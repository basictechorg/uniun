part of 'create_group_bloc.dart';

@immutable
class CreateGroupState {
  final bool isLoadingRelays;
  final List<String> availableRelays;
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  const CreateGroupState({
    this.isLoadingRelays = false,
    this.availableRelays = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  CreateGroupState copyWith({
    bool? isLoadingRelays,
    List<String>? availableRelays,
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return CreateGroupState(
      isLoadingRelays: isLoadingRelays ?? this.isLoadingRelays,
      availableRelays: availableRelays ?? this.availableRelays,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}
