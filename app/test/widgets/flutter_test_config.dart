import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/theme/app_text.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget and golden tests draw with the real fonts: the bundled Bricolage
/// Grotesque and DM Sans files and the Lucide icon font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureFonts();
  // Touching each style makes google_fonts load its bundled file.
  final styles = [
    AppText.displayXL, AppText.displayM, AppText.titleM, AppText.bodyL, AppText.labelS, AppText.overline,
  ];
  assert(styles.every((s) => s.fontFamily != null));
  await GoogleFonts.pendingFonts();
  final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
  await icons.load();
  return testMain();
}
