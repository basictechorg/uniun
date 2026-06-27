part of 'join_channel_bloc.dart';

/// Validation/failure reasons surfaced to the join-channel UI. The widget layer
/// maps these to localized strings (the bloc has no BuildContext).
enum JoinChannelError { invalidId, noRelay, relaySaveFailed, saveFailed }

@immutable
class JoinChannelState {
  const JoinChannelState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
  });

  final bool isSubmitting;
  final bool isSuccess;
  final JoinChannelError? error;

  JoinChannelState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    JoinChannelError? error,
  }) {
    return JoinChannelState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}
