import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Centralised snackbar helpers. Every error / success toast in the app
/// should go through these so styling stays consistent and we have one
/// place to swap implementations (toast, banner, etc.) later.
///
/// Pass a captured [ScaffoldMessengerState] when the call site spans an
/// async gap that may invalidate the original [BuildContext] (picker
/// pipelines, navigation pops, etc.). Otherwise use the context overloads.
class AppSnackbar {
  AppSnackbar._();

  static void error(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(_errorBar(message));
  }

  static void success(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(_successBar(message));
  }

  static void errorVia(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(_errorBar(message));
  }

  static void successVia(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(_successBar(message));
  }

  static SnackBar _errorBar(String message) => SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      );

  static SnackBar _successBar(String message) => SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      );
}
