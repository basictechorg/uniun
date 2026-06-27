part of 'join_group_bloc.dart';

/// Validation/failure reasons surfaced to the join-group UI. The widget layer
/// maps these to localized strings (the bloc has no BuildContext).
enum JoinGroupError { invalidId, noRelay, relaySaveFailed, saveFailed }

@immutable
class JoinGroupState {
  const JoinGroupState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
  });

  final bool isSubmitting;
  final bool isSuccess;
  final JoinGroupError? error;

  JoinGroupState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    JoinGroupError? error,
  }) {
    return JoinGroupState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}
