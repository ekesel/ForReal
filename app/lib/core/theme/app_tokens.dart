/// Spacing, radii and sizes from the design system.
class AppSpace {
  const AppSpace._();
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;

  /// Horizontal padding of every screen.
  static const double screen = 20;
}

class AppRadius {
  const AppRadius._();
  static const double r10 = 10;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double pill = 999;
}

class AppSize {
  const AppSize._();
  static const double button = 54;
  static const double chip = 38;

  /// Smallest area a finger can reliably hit.
  static const double touch = 48;
  static const double line = 1;
  static const double lineStrong = 1.5;
}

/// Short and unobtrusive: page transitions and row state changes only.
class AppMotion {
  const AppMotion._();
  static const Duration quick = Duration(milliseconds: 180);
}
