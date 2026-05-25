part of 'create_channel_bloc.dart';

@immutable
class CreateChannelState {
  final bool isLoadingRelays;
  final List<String> availableRelays;
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  const CreateChannelState({
    this.isLoadingRelays = false,
    this.availableRelays = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  CreateChannelState copyWith({
    bool? isLoadingRelays,
    List<String>? availableRelays,
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return CreateChannelState(
      isLoadingRelays: isLoadingRelays ?? this.isLoadingRelays,
      availableRelays: availableRelays ?? this.availableRelays,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}
