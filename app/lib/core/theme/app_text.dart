import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// The type scale: Bricolage Grotesque for display and titles, DM Sans for the rest.
///
/// Fonts are bundled in `google_fonts/` and never fetched at runtime (see
/// [configureFonts]). Styles carry no colour; widgets add the right ink token.
class AppText {
  const AppText._();

  static TextStyle _display(double size, double height, FontWeight weight, double trackingPercent) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: size * trackingPercent / 100,
      );

  static TextStyle _sans(double size, double height, FontWeight weight, [double trackingPercent = 0]) =>
      GoogleFonts.dmSans(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: size * trackingPercent / 100,
      );

  static TextStyle get displayXL => _display(40, 44, FontWeight.w800, -1.5);
  static TextStyle get displayL => _display(30, 34, FontWeight.w800, -1);
  static TextStyle get displayM => _display(24, 30, FontWeight.w700, -0.5);
  static TextStyle get titleL => _display(20, 26, FontWeight.w700, -0.3);
  static TextStyle get titleM => _sans(17, 24, FontWeight.w600);
  static TextStyle get bodyL => _sans(16, 24, FontWeight.w400);
  static TextStyle get bodyM => _sans(14, 20, FontWeight.w400);
  static TextStyle get labelL => _sans(15, 20, FontWeight.w600);
  static TextStyle get labelM => _sans(13, 18, FontWeight.w600);
  static TextStyle get labelS => _sans(12, 16, FontWeight.w500);
  static TextStyle get caption => _sans(12, 16, FontWeight.w400);

  /// Always shown in upper case; see SectionLabel.
  static TextStyle get overline => _sans(11, 14, FontWeight.w700, 8);

  /// The app follows the system text size up to this factor.
  static const double maxTextScale = 1.3;
}

/// Call once per isolate that draws UI, before the first frame.
void configureFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
}
