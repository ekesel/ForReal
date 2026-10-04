import 'package:flutter/material.dart';

/// The ForReal palette: warm paper, ink and marigold.
///
/// Colour carries meaning, so use the tokens by role, never by look:
///  - [brand] (marigold): something needs the user, or the primary action on the
///    welcome screen.
///  - [real] (green): only for things confirmed by a real payment or by the user.
///    An AI guess is never green.
///  - [ink] with [onInk]: primary buttons and selected states.
///  - [danger] on [dangerSoft]: destructive actions and "capture is off".
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.real,
    required this.realSoft,
    required this.onInk,
    required this.danger,
    required this.dangerSoft,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color line;
  final Color brand;
  final Color onBrand;
  final Color brandSoft;
  final Color real;
  final Color realSoft;
  final Color onInk;
  final Color danger;
  final Color dangerSoft;

  static const light = AppColors(
    bg: Color(0xFFFAF6EF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1EBE0),
    ink: Color(0xFF16130F),
    inkMuted: Color(0xFF6B645A),
    inkFaint: Color(0xFFA59D90),
    line: Color(0xFFE4DCCD),
    brand: Color(0xFFFFB000),
    onBrand: Color(0xFF16130F),
    brandSoft: Color(0xFFFFF1CC),
    real: Color(0xFF0E9F6E),
    realSoft: Color(0xFFDDF5EA),
    onInk: Color(0xFFFAF6EF),
    danger: Color(0xFFD6402B),
    dangerSoft: Color(0xFFFBE3DE),
  );

  static const dark = AppColors(
    bg: Color(0xFF121110),
    surface: Color(0xFF1C1A18),
    surfaceAlt: Color(0xFF262320),
    ink: Color(0xFFF6F1E8),
    inkMuted: Color(0xFFA79F93),
    inkFaint: Color(0xFF6F685E),
    line: Color(0xFF34302B),
    brand: Color(0xFFFFB000),
    onBrand: Color(0xFF16130F),
    brandSoft: Color(0xFF3A2E0C),
    real: Color(0xFF34D399),
    realSoft: Color(0xFF0F2E24),
    onInk: Color(0xFF121110),
    danger: Color(0xFFF0705C),
    dangerSoft: Color(0xFF3A1711),
  );

  static AppColors of(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  ColorScheme toColorScheme(Brightness brightness) => ColorScheme(
        brightness: brightness,
        primary: ink,
        onPrimary: onInk,
        primaryContainer: surfaceAlt,
        onPrimaryContainer: ink,
        secondary: brand,
        onSecondary: onBrand,
        secondaryContainer: brandSoft,
        onSecondaryContainer: ink,
        tertiary: real,
        onTertiary: onInk,
        tertiaryContainer: realSoft,
        onTertiaryContainer: real,
        error: danger,
        onError: onInk,
        errorContainer: dangerSoft,
        onErrorContainer: danger,
        surface: bg,
        onSurface: ink,
        onSurfaceVariant: inkMuted,
        surfaceContainerLowest: surface,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: surfaceAlt,
        surfaceContainerHighest: surfaceAlt,
        outline: inkFaint,
        outlineVariant: line,
        inverseSurface: ink,
        onInverseSurface: onInk,
        inversePrimary: brand,
        shadow: ink,
        scrim: ink,
      );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      line: mix(line, other.line),
      brand: mix(brand, other.brand),
      onBrand: mix(onBrand, other.onBrand),
      brandSoft: mix(brandSoft, other.brandSoft),
      real: mix(real, other.real),
      realSoft: mix(realSoft, other.realSoft),
      onInk: mix(onInk, other.onInk),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The palette for the current theme.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// WCAG contrast ratio between two opaque colours (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
