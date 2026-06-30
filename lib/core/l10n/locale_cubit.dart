import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/l10n/app_language.dart';
import 'package:uniun/domain/usecases/app_settings_usecases.dart';

/// Holds the app's current [Locale] and drives `MaterialApp.locale`. Provided
/// once at the top of the widget tree (above `MaterialApp.router`); a
/// `BlocBuilder<LocaleCubit, Locale>` there rebuilds the whole app on switch.
///
/// The *initial* locale is resolved synchronously in `main()` (via
/// [resolveInitial]) and passed in, so there's no first-frame flicker. Every
/// runtime switch persists through [SetAppLocaleUseCase].
class LocaleCubit extends Cubit<Locale> {
  final SetAppLocaleUseCase _setLocale;

  LocaleCubit(this._setLocale, {required Locale initial}) : super(initial);

  /// The [AppLanguage] matching the active locale (defaults to English if the
  /// code is somehow unknown).
  AppLanguage get activeLanguage =>
      AppLanguage.fromCode(state.languageCode) ?? AppLanguage.english;

  /// Switch to [language] and persist the choice. No-ops for languages that
  /// don't ship translations yet, or when it's already active.
  Future<void> setLanguage(AppLanguage language) async {
    if (!language.supported) return;
    if (state.languageCode == language.code) return;
    emit(Locale(language.code));
    await _setLocale(language.code);
  }

  /// Pick the locale to start in: the saved choice if it's a supported language,
  /// else the first supported system locale, else English.
  static Locale resolveInitial({
    required String? savedCode,
    required List<Locale> systemLocales,
  }) {
    final saved = AppLanguage.fromCode(savedCode);
    if (saved != null && saved.supported) return Locale(saved.code);

    for (final sys in systemLocales) {
      final match = AppLanguage.fromCode(sys.languageCode);
      if (match != null && match.supported) return Locale(match.code);
    }
    return const Locale('en');
  }
}
