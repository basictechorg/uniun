part of 'join_channel_bloc.dart';

@immutable
class JoinChannelState {
  const JoinChannelState({
    this.isLoadingRelays = false,
    this.availableRelays = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  final bool isLoadingRelays;
  final List<String> availableRelays;
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  JoinChannelState copyWith({
    bool? isLoadingRelays,
    List<String>? availableRelays,
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return JoinChannelState(
      isLoadingRelays: isLoadingRelays ?? this.isLoadingRelays,
      availableRelays: availableRelays ?? this.availableRelays,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}
