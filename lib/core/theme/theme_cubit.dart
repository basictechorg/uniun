import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';
import 'package:uniun/domain/usecases/app_settings_usecases.dart';

/// Holds the app's active [AppThemeMode] and drives `MaterialApp.themeMode`.
/// Provided once at the root; a `BlocBuilder<ThemeCubit, AppThemeMode>` there
/// rebuilds the app on switch.
///
/// The initial value is resolved synchronously in `main()` from
/// `AppSettingsStore.themeMode` (defaults to [AppThemeMode.system]) so the
/// first frame is already in the right theme. Runtime switches persist
/// through [SetThemeModeUseCase].
class ThemeCubit extends Cubit<AppThemeMode> {
  final SetThemeModeUseCase _setThemeMode;

  ThemeCubit(this._setThemeMode, {required AppThemeMode initial})
      : super(initial);

  Future<void> setMode(AppThemeMode mode) async {
    if (state == mode) return;
    emit(mode);
    await _setThemeMode(mode);
  }
}
