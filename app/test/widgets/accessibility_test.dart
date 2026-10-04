import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/auth/phone_screen.dart';
import 'package:forreal/features/auth/welcome_screen.dart';
import 'package:forreal/features/home/coming_soon_screen.dart';
import 'package:forreal/features/home/home_screen.dart';
import 'package:forreal/features/items/items_screen.dart';
import 'package:forreal/features/onboarding/onboarding_screen.dart';
import 'package:forreal/features/payee/payee_screen.dart';
import 'package:forreal/features/settings/settings_screen.dart';
import 'package:forreal/features/transaction/transaction_detail_screen.dart';

import '../support/fakes.dart';
import '../support/harness.dart';
import 'support.dart';

/// Flutter's accessibility guidelines on the main screens, in light and dark:
/// every tap target at least 48 px, every tap target labelled.
void main() {
  late Harness h;

  setUp(() {
    h = Harness();
    h.serveConsents();
    h.serveTemplates();
    h.api.reply('PUT', 'me/device/', {'device_id': 'x'});
    h.api.reply('GET', 'payees/7/suggestions/', {
      'payee': {'id': 7, 'name': 'X'},
      'crowd': [teaStall],
    });
    h.api.reply('GET', 'items/', {
      'items': [
        {'id': 3, 'name': 'Tea', 'category': 'tea-stall'},
        {'id': 4, 'name': 'Samosa', 'category': 'tea-stall'},
      ]
    });
  });
  tearDown(() => h.dispose());

  final tagged = row('a', kind: 'merchant', merchant: teaStall, ask: 'items', amount: 55, items: [guess('Tea')]);
  final done = row('d', kind: 'merchant', merchant: teaStall, ask: null, items: [guess('Tea', inferred: false)]);

  final screens = <String, (Widget, List)>{
    'welcome': (const WelcomeScreen(), const []),
    'phone': (const PhoneScreen(), const []),
    'onboarding': (const OnboardingScreen(), const []),
    'home': (const HomeScreen(), designRows()),
    'discover': (const ComingSoonScreen.discover(), const []),
    'detail': (const TransactionDetailScreen(clientTxnId: 'd'), [done]),
    'payee': (const PayeeScreen(clientTxnId: 'a'), [row('a')]),
    'items': (const ItemsScreen(clientTxnId: 'a'), [tagged]),
    'settings': (const SettingsScreen(), const []),
  };

  for (final brightness in Brightness.values) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key}: tap targets are 48 px and labelled (${brightness.name})', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.runAsync(() async {
          await h.session.onSignedIn(AuthSession.fromJson({
            'access': 'access-1',
            'refresh': 'refresh-1',
            'is_new_user': true,
            'user': {'id': 'u', 'phone': '+919876543210', 'display_name': ''},
          }));
          await h.session.setConsent(Purpose.privateAnalytics, true);
        });
        setSurface(tester, const Size(412, 1500));
        await tester.pumpWidget(screen(h, entry.value.$1, rows: entry.value.$2.cast(), brightness: brightness));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  }
}
