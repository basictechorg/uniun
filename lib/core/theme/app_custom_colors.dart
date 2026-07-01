import 'package:flutter/material.dart';

/// Design tokens that don't map to Material 3 `ColorScheme` — graph node
/// palette, storage bars, glass surfaces, semantic success, muted text tones,
/// redesign shadows. Registered on both light and dark [ThemeData.extensions];
/// read via `context.custom`.
@immutable
class AppCustomColors extends ThemeExtension<AppCustomColors> {
  final Color iconInactive;

  final Color graphSaved;
  final Color graphOwn;
  final Color graphDraft;

  final Color graphNodeSaved;
  final Color graphNodeOwn;
  final Color graphNodeDraft;
  final Color graphDotPattern;
  final Color graphEdge;

  final Color neutral300;
  final Color neutral400;

  final Color borderSubtle;
  final Color border;
  final Color surfaceLow;

  final Color textBody;
  final Color textMuted;

  final Color success;
  final Color onSuccess;

  final Color storageNotes;
  final Color storageModel;
  final Color storageChatHistory;
  final Color storageOther;

  final Color glassFill;
  final Color glassBorder;

  final Color navShadow;
  final Color elevationMd;
  final Color shadowPrimary;

  const AppCustomColors({
    required this.iconInactive,
    required this.graphSaved,
    required this.graphOwn,
    required this.graphDraft,
    required this.graphNodeSaved,
    required this.graphNodeOwn,
    required this.graphNodeDraft,
    required this.graphDotPattern,
    required this.graphEdge,
    required this.neutral300,
    required this.neutral400,
    required this.borderSubtle,
    required this.border,
    required this.surfaceLow,
    required this.textBody,
    required this.textMuted,
    required this.success,
    required this.onSuccess,
    required this.storageNotes,
    required this.storageModel,
    required this.storageChatHistory,
    required this.storageOther,
    required this.glassFill,
    required this.glassBorder,
    required this.navShadow,
    required this.elevationMd,
    required this.shadowPrimary,
  });

  static const AppCustomColors light = AppCustomColors(
    iconInactive: Color(0xFFCACCCE),
    graphSaved: Color(0xFF0075F2),
    graphOwn: Color(0xFF059669),
    graphDraft: Color(0xFFD97706),
    graphNodeSaved: Color(0xFF0075F2),
    graphNodeOwn: Color(0xFF6FB0F8),
    graphNodeDraft: Color(0xFF00458E),
    graphDotPattern: Color(0xFFE2E8F0),
    graphEdge: Color(0xFFCBD5E1),
    neutral300: Color(0xFFCBD3DF),
    neutral400: Color(0xFFA7B0BE),
    borderSubtle: Color(0xFFEEF2F7),
    border: Color(0xFFDEE4EC),
    surfaceLow: Color(0xFFF4F7FB),
    textBody: Color(0xFF1E293B),
    textMuted: Color(0xFF6B7480),
    success: Color(0xFF059669),
    onSuccess: Color(0xFFFFFFFF),
    storageNotes: Color(0xFF319BED),
    storageModel: Color(0xFF4CAF50),
    storageChatHistory: Color(0xFFFF9800),
    storageOther: Color(0xFF9E9E9E),
    glassFill: Color(0xB8FFFFFF),
    glassBorder: Color(0x4DFFFFFF),
    navShadow: Color(0x24005AB6),
    elevationMd: Color(0x1415181C),
    shadowPrimary: Color(0x3D0075F2),
  );

  static const AppCustomColors dark = AppCustomColors(
    iconInactive: Color(0xFF55595F),
    graphSaved: Color(0xFF5EA0FF),
    graphOwn: Color(0xFF34D399),
    graphDraft: Color(0xFFF59E0B),
    graphNodeSaved: Color(0xFF5EA0FF),
    graphNodeOwn: Color(0xFF93C5FD),
    graphNodeDraft: Color(0xFF003E80),
    graphDotPattern: Color(0xFF1E2230),
    graphEdge: Color(0xFF334155),
    neutral300: Color(0xFF40454E),
    // Inactive nav-foreground in dark mode: lifted so unselected floating-nav
    // tabs (Vishnu / Shiv) stay readable against the dark glass pill. Light
    // uses #A7B0BE; dark needs to sit ~2 shades brighter than that on the
    // deeper surface to hit AA contrast.
    neutral400: Color(0xFFB8C0CD),
    borderSubtle: Color(0xFF23272B),
    border: Color(0xFF2E3236),
    surfaceLow: Color(0xFF171B1E),
    textBody: Color(0xFFE1E2E4),
    textMuted: Color(0xFF9CA3AF),
    success: Color(0xFF34D399),
    onSuccess: Color(0xFF001B10),
    storageNotes: Color(0xFF5EA0FF),
    storageModel: Color(0xFF66BB6A),
    storageChatHistory: Color(0xFFFFB74D),
    storageOther: Color(0xFFBDBDBD),
    glassFill: Color(0xB8272B2E),
    glassBorder: Color(0x4D2E3236),
    // Dial shadows down in dark — big lifts look like halos against deep surface.
    navShadow: Color(0x1200334D),
    elevationMd: Color(0x29000000),
    shadowPrimary: Color(0x1F0075F2),
  );

  @override
  AppCustomColors copyWith({
    Color? iconInactive,
    Color? graphSaved,
    Color? graphOwn,
    Color? graphDraft,
    Color? graphNodeSaved,
    Color? graphNodeOwn,
    Color? graphNodeDraft,
    Color? graphDotPattern,
    Color? graphEdge,
    Color? neutral300,
    Color? neutral400,
    Color? borderSubtle,
    Color? border,
    Color? surfaceLow,
    Color? textBody,
    Color? textMuted,
    Color? success,
    Color? onSuccess,
    Color? storageNotes,
    Color? storageModel,
    Color? storageChatHistory,
    Color? storageOther,
    Color? glassFill,
    Color? glassBorder,
    Color? navShadow,
    Color? elevationMd,
    Color? shadowPrimary,
  }) {
    return AppCustomColors(
      iconInactive: iconInactive ?? this.iconInactive,
      graphSaved: graphSaved ?? this.graphSaved,
      graphOwn: graphOwn ?? this.graphOwn,
      graphDraft: graphDraft ?? this.graphDraft,
      graphNodeSaved: graphNodeSaved ?? this.graphNodeSaved,
      graphNodeOwn: graphNodeOwn ?? this.graphNodeOwn,
      graphNodeDraft: graphNodeDraft ?? this.graphNodeDraft,
      graphDotPattern: graphDotPattern ?? this.graphDotPattern,
      graphEdge: graphEdge ?? this.graphEdge,
      neutral300: neutral300 ?? this.neutral300,
      neutral400: neutral400 ?? this.neutral400,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      border: border ?? this.border,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      textBody: textBody ?? this.textBody,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      storageNotes: storageNotes ?? this.storageNotes,
      storageModel: storageModel ?? this.storageModel,
      storageChatHistory: storageChatHistory ?? this.storageChatHistory,
      storageOther: storageOther ?? this.storageOther,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      navShadow: navShadow ?? this.navShadow,
      elevationMd: elevationMd ?? this.elevationMd,
      shadowPrimary: shadowPrimary ?? this.shadowPrimary,
    );
  }

  @override
  AppCustomColors lerp(ThemeExtension<AppCustomColors>? other, double t) {
    if (other is! AppCustomColors) return this;
    return AppCustomColors(
      iconInactive: Color.lerp(iconInactive, other.iconInactive, t)!,
      graphSaved: Color.lerp(graphSaved, other.graphSaved, t)!,
      graphOwn: Color.lerp(graphOwn, other.graphOwn, t)!,
      graphDraft: Color.lerp(graphDraft, other.graphDraft, t)!,
      graphNodeSaved: Color.lerp(graphNodeSaved, other.graphNodeSaved, t)!,
      graphNodeOwn: Color.lerp(graphNodeOwn, other.graphNodeOwn, t)!,
      graphNodeDraft: Color.lerp(graphNodeDraft, other.graphNodeDraft, t)!,
      graphDotPattern: Color.lerp(graphDotPattern, other.graphDotPattern, t)!,
      graphEdge: Color.lerp(graphEdge, other.graphEdge, t)!,
      neutral300: Color.lerp(neutral300, other.neutral300, t)!,
      neutral400: Color.lerp(neutral400, other.neutral400, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      storageNotes: Color.lerp(storageNotes, other.storageNotes, t)!,
      storageModel: Color.lerp(storageModel, other.storageModel, t)!,
      storageChatHistory:
          Color.lerp(storageChatHistory, other.storageChatHistory, t)!,
      storageOther: Color.lerp(storageOther, other.storageOther, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      navShadow: Color.lerp(navShadow, other.navShadow, t)!,
      elevationMd: Color.lerp(elevationMd, other.elevationMd, t)!,
      shadowPrimary: Color.lerp(shadowPrimary, other.shadowPrimary, t)!,
    );
  }
}

/// Shorthand accessor so widgets can write `context.custom.textMuted` instead
/// of `Theme.of(context).extension<AppCustomColors>()!.textMuted`.
extension AppCustomColorsContext on BuildContext {
  AppCustomColors get custom =>
      Theme.of(this).extension<AppCustomColors>() ?? AppCustomColors.light;
}
