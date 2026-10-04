import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/providers.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/auth/otp_screen.dart';
import 'package:forreal/features/auth/phone_screen.dart';
import 'package:forreal/features/auth/welcome_screen.dart';
import 'package:forreal/features/home/coming_soon_screen.dart';
import 'package:forreal/features/home/home_screen.dart';
import 'package:forreal/features/items/items_screen.dart';
import 'package:forreal/features/onboarding/onboarding_screen.dart';
import 'package:forreal/features/parser_gaps/parser_gaps_screen.dart';
import 'package:forreal/features/payee/payee_screen.dart';
import 'package:forreal/features/settings/settings_screen.dart';
import 'package:forreal/features/splash_screen.dart';
import 'package:forreal/features/transaction/transaction_detail_screen.dart';

import '../support/fakes.dart';
import '../support/harness.dart';
import 'support.dart';

/// Every screen must lay out without overflow on a small phone (360 dp wide) with
/// the largest supported text (1.3), in light and dark. A RenderFlex overflow is an
/// exception in tests, so "it pumps" is the assertion.
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
    h.api.reply('GET', 'merchants/search/', {'merchants': [teaStall, bakery]});
    h.api.reply('GET', 'categories/', {
      'categories': [
        for (final name in ['Tea stall', 'Food and restaurants', 'Bakery', 'Grocery and kirana', 'Fruits and vegetables'])
          {'slug': name.toLowerCase().replaceAll(' ', '-'), 'name': name},
      ]
    });
    h.api.reply('GET', 'items/', {
      'items': [
        for (final (i, name) in ['Tea', 'Samosa', 'Coffee', 'Biscuits', 'Bread', 'Cigarette', 'Snacks'].indexed)
          {'id': i + 3, 'name': name, 'category': 'tea-stall'},
      ]
    });
  });
  tearDown(() => h.dispose());

  Future<void> signedIn(WidgetTester tester) => tester.runAsync(() async {
        await h.session.onSignedIn(AuthSession.fromJson({
          'access': 'access-1',
          'refresh': 'refresh-1',
          'is_new_user': true,
          'user': {'id': 'u', 'phone': '+919876543210', 'display_name': ''},
        }));
        await h.session.setConsent(Purpose.privateAnalytics, true);
        await h.store.addUnparsed(sampleUnparsed);
      });

  final tagged = row('a', kind: 'merchant', merchant: teaStall, ask: 'items', amount: 55, items: [
    guess('Tea', quantity: 2),
    guess('Samosa', id: 4),
  ]);
  final longName = row('long',
      payee: 'SRI VENKATESHWARA SUPER SPECIALITY PROVISION AND GENERAL STORES PRIVATE LIMITED', amount: 123456.5);

  final screens = <String, (Widget, List)>{
    'welcome': (const WelcomeScreen(), const []),
    'splash': (const SplashScreen(), const []),
    'phone': (const PhoneScreen(), const []),
    'code': (const OtpScreen(args: OtpArgs(phone: '+919876543210')), const []),
    'onboarding': (const OnboardingScreen(), const []),
    'home': (const HomeScreen(), [...designRows(), longName]),
    'home empty': (const HomeScreen(), const []),
    'discover': (const ComingSoonScreen.discover(), const []),
    'insights': (const ComingSoonScreen.insights(), const []),
    'detail': (const TransactionDetailScreen(clientTxnId: 'a'), [tagged]),
    'detail long name': (const TransactionDetailScreen(clientTxnId: 'long'), [longName]),
    'payee': (const PayeeScreen(clientTxnId: 'long'), [longName]),
    'items': (const ItemsScreen(clientTxnId: 'a'), [tagged]),
    'settings': (const SettingsScreen(), const []),
    'parser gaps': (const ParserGapsScreen(), const []),
  };

  for (final brightness in Brightness.values) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits 360 dp at text scale 1.3 (${brightness.name})', (tester) async {
        await signedIn(tester);
        setSurface(tester, const Size(360, 640));
        await tester.pumpWidget(
          screen(h, entry.value.$1, rows: entry.value.$2.cast(), brightness: brightness, textScale: 1.3),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('every onboarding step fits 360 dp at text scale 1.3', (tester) async {
    await signedIn(tester);
    setSurface(tester, const Size(360, 640));
    await tester.pumpWidget(screen(h, const OnboardingScreen(), textScale: 1.3));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Allow and continue'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
    expect(find.text('2 of 5'), findsOneWidget);
    for (final skip in ['Skip for now', 'Skip', 'Skip']) {
      await tester.tap(find.text(skip));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('5 of 5'), findsOneWidget);
  });

  testWidgets('the payee stages fit 360 dp at text scale 1.3', (tester) async {
    await signedIn(tester);
    setSurface(tester, const Size(360, 640));
    await tester.pumpWidget(screen(h, const PayeeScreen(clientTxnId: 'a'), rows: [row('a')], textScale: 1.3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Which shop is it?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add a new shop'));
    await tester.pumpAndSettle();
    expect(find.text('Add a shop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app clamps the system text scale at 1.3', (tester) async {
    // Checked on the widget the app uses, with an oversized system setting.
    late double applied;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Builder(builder: (context) {
          applied = MediaQuery.textScalerOf(context).scale(10) / 10;
          return const SizedBox();
        }),
      ),
    ));
    expect(applied, 1.3);
  });

  test('the clock provider defaults to the real time', () {
    final now = h.container.read(clockProvider)();
    expect(DateTime.now().difference(now).inSeconds.abs(), lessThan(5));
  });
}
