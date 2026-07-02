import 'package:flutter/material.dart';
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
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(_errorBar(message, Theme.of(context).colorScheme.error));
  }

  static void success(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        _successBar(message, Theme.of(context).colorScheme.primary));
  }

  static void errorVia(ScaffoldMessengerState messenger, String message) {
    // Falls back to the platform's default red — this overload is called from
    // async gaps where no BuildContext is available.
    messenger.showSnackBar(_errorBar(message, const Color(0xFFBA1A1A)));
  }

  static void successVia(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(_successBar(message, const Color(0xFF0075F2)));
  }

  static SnackBar _errorBar(String message, Color background) => SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      );

  static SnackBar _successBar(String message, Color background) => SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      );
}
