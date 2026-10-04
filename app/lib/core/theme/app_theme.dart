import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';
import 'app_tokens.dart';

export 'app_colors.dart';
export 'app_text.dart';
export 'app_tokens.dart';

/// Material theme built from the design tokens. Light and dark share everything
/// except the palette.
ThemeData appTheme(Brightness brightness) {
  final c = AppColors.of(brightness);
  final scheme = c.toColorScheme(brightness);

  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displayLarge: AppText.displayXL,
      displayMedium: AppText.displayL,
      displaySmall: AppText.displayM,
      headlineSmall: AppText.displayM,
      titleLarge: AppText.titleL,
      titleMedium: AppText.titleM,
      titleSmall: AppText.labelL,
      bodyLarge: AppText.bodyL,
      bodyMedium: AppText.bodyM,
      bodySmall: AppText.caption,
      labelLarge: AppText.labelL,
      labelMedium: AppText.labelM,
      labelSmall: AppText.labelS,
    ).apply(bodyColor: c.ink, displayColor: c.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.titleL.copyWith(color: c.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: AppSpace.x16),
      hintStyle: AppText.bodyL.copyWith(color: c.inkFaint),
      errorStyle: AppText.caption.copyWith(color: c.danger),
      errorMaxLines: 3,
      enabledBorder: border(c.line, AppSize.line),
      border: border(c.line, AppSize.line),
      focusedBorder: border(c.ink, AppSize.lineStrong),
      errorBorder: border(c.danger, AppSize.line),
      focusedErrorBorder: border(c.danger, AppSize.lineStrong),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.ink,
      selectionColor: c.brandSoft,
      selectionHandleColor: c.brand,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: AppText.bodyM.copyWith(color: c.onInk),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r24)),
      titleTextStyle: AppText.titleL.copyWith(color: c.ink),
      contentTextStyle: AppText.bodyM.copyWith(color: c.inkMuted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: c.bg,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r24)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.ink, linearTrackColor: c.line),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
