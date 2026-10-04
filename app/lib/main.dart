import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/theme/app_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts come from the bundled assets only; the app never fetches them.
  configureFonts();
  LicenseRegistry.addLicense(() async* {
    for (final file in const ['OFL-BricolageGrotesque.txt', 'OFL-DMSans.txt']) {
      yield LicenseEntryWithLineBreaks(const ['google_fonts'], await rootBundle.loadString('google_fonts/$file'));
    }
  });
  runApp(ProviderScope(overrides: platformOverrides(background: false), child: const ForRealApp()));
}
