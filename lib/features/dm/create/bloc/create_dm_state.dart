part of 'create_dm_bloc.dart';

@immutable
class CreateDmState {
  final bool isLoadingRelays;
  final List<String> availableRelays;
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  const CreateDmState({
    this.isLoadingRelays = false,
    this.availableRelays = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  CreateDmState copyWith({
    bool? isLoadingRelays,
    List<String>? availableRelays,
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return CreateDmState(
      isLoadingRelays: isLoadingRelays ?? this.isLoadingRelays,
      availableRelays: availableRelays ?? this.availableRelays,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}
