import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/widgets.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/auth/welcome_screen.dart';
import 'package:forreal/features/home/home_screen.dart';
import 'package:forreal/features/items/items_screen.dart';
import 'package:forreal/features/payee/payee_screen.dart';
import 'package:forreal/features/settings/settings_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/fakes.dart';
import '../support/harness.dart';
import 'support.dart';

/// Golden images of the shared widgets and of five screens, in light and dark.
///
/// Regenerate after an intended visual change:
///   flutter test --update-goldens test/widgets/golden_test.dart
/// The images are rendered by the Flutter test engine on Linux; text rendering
/// differs slightly on macOS and Windows, so compare on the same platform.
void main() {
  late Harness h;

  setUp(() {
    h = Harness();
    h.serveConsents();
    h.serveTemplates();
    h.api.reply('PUT', 'me/device/', {'device_id': 'x'});
    h.api.reply('GET', 'payees/7/suggestions/', {
      'payee': {'id': 7, 'name': 'X'},
      'crowd': [],
    });
    h.api.reply('GET', 'items/', {
      'items': [
        for (final (i, name) in ['Tea', 'Samosa', 'Coffee', 'Biscuits', 'Bread', 'Cigarette', 'Snacks'].indexed)
          {'id': i + 3, 'name': name, 'category': 'tea-stall'},
      ]
    });
  });
  tearDown(() => h.dispose());

  Future<void> signedIn(WidgetTester tester, {bool community = true, bool location = true}) => tester.runAsync(() async {
        await h.session.onSignedIn(AuthSession.fromJson({
          'access': 'access-1',
          'refresh': 'refresh-1',
          'is_new_user': true,
          'user': {'id': 'u', 'phone': '+919876543210', 'display_name': ''},
        }));
        await h.session.setConsent(Purpose.privateAnalytics, true);
        if (community) await h.session.setConsent(Purpose.communityRankings, true);
        if (location) await h.session.setConsent(Purpose.location, true);
      });

  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    testWidgets('shared widgets ($theme)', (tester) async {
      setSurface(tester, const Size(412, 1560));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(brightness),
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(active: AppTab.payments, onSelect: (_) {}),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StepHeader(step: 2, onBack: () {}),
                  const SizedBox(height: 12),
                  Row(children: [
                    const IconTile(icon: LucideIcons.messageSquare),
                    const SizedBox(width: 12),
                    Expanded(child: SectionLabel('Section label')),
                    AppToggle(value: true, onChanged: (_) {}),
                    const SizedBox(width: 8),
                    AppToggle(value: false, onChanged: (_) {}),
                  ]),
                  const SizedBox(height: 12),
                  AppButton(label: 'Primary', onPressed: () {}),
                  const SizedBox(height: 8),
                  AppButton(label: 'Brand', variant: AppButtonVariant.brand, onPressed: () {}),
                  const SizedBox(height: 8),
                  AppButton(label: 'Secondary', variant: AppButtonVariant.secondary, onPressed: () {}),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: AppButton(label: 'Ghost', variant: AppButtonVariant.ghost, onPressed: () {})),
                    Expanded(child: AppButton(label: 'Danger', variant: AppButtonVariant.danger, onPressed: () {})),
                    const SizedBox(width: 8),
                    const Expanded(child: AppButton(label: 'Disabled', onPressed: null)),
                  ]),
                  const SizedBox(height: 8),
                  const Wrap(spacing: 8, children: [
                    AppChip(label: 'Chip'),
                    AppChip(label: 'Selected', variant: AppChipVariant.selected),
                    AppChip(label: 'Guess', variant: AppChipVariant.guess),
                    AppChip(label: 'Real', variant: AppChipVariant.real),
                  ]),
                  const SizedBox(height: 8),
                  const AppTextField(label: 'Shop name', hint: 'What people call it', helper: 'A helper line'),
                  const SizedBox(height: 12),
                  const AppCard(outlined: true, child: Text('Outlined card')),
                  const SizedBox(height: 8),
                  const AppCard(selected: true, child: Text('Selected card')),
                  const SizedBox(height: 12),
                  const InfoBanner(icon: LucideIcons.shieldCheck, tone: BannerTone.real, text: 'Payments to people are never counted.'),
                  const SizedBox(height: 8),
                  const InfoBanner(icon: LucideIcons.sparkle, tone: BannerTone.brand, text: 'Our guess: Tea × 2, Samosa'),
                  const SizedBox(height: 8),
                  InfoBanner(
                    icon: LucideIcons.messageSquare,
                    tone: BannerTone.danger,
                    title: 'Capture is off',
                    text: 'Allow SMS access so payments show up on their own.',
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  for (final (state, detail) in [
                    (PaymentRowState.needsShop, null),
                    (PaymentRowState.needsItems, null),
                    (PaymentRowState.done, 'Tea · Samosa'),
                    (PaymentRowState.guessed, 'Tea'),
                    (PaymentRowState.person, null),
                  ]) ...[
                    PaymentRow(title: 'Sharma Tea Stall', state: state, detail: detail, amount: '₹55', time: 'Today'),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/shared_widgets_$theme.png'));
    });

    testWidgets('welcome ($theme)', (tester) async {
      setSurface(tester, const Size(412, 892));
      await tester.pumpWidget(screen(h, const WelcomeScreen(), brightness: brightness));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/welcome_$theme.png'));
    });

    testWidgets('payments home ($theme)', (tester) async {
      await signedIn(tester);
      setSurface(tester, const Size(412, 990));
      await tester.pumpWidget(screen(h, const HomeScreen(), rows: designRows(), brightness: brightness));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/payments_home_$theme.png'));
    });

    testWidgets('shop or person ($theme)', (tester) async {
      await signedIn(tester);
      setSurface(tester, const Size(412, 892));
      final rows = [row('a'), row('b', at: DateTime(2026, 10, 2, 9))];
      await tester.pumpWidget(screen(h, const PayeeScreen(clientTxnId: 'a'), rows: rows, brightness: brightness));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/shop_or_person_$theme.png'));
    });

    testWidgets('what did you get ($theme)', (tester) async {
      await signedIn(tester);
      setSurface(tester, const Size(412, 892));
      final tagged = row('a',
          kind: 'merchant',
          merchant: teaStall,
          ask: 'items',
          amount: 55,
          at: DateTime(2026, 10, 7, 16, 10),
          items: [
            {...guess('Tea', quantity: 2), 'origin': 'ai_own_history'},
            {...guess('Samosa', id: 4), 'origin': 'ai_own_history'},
          ]);
      await tester.pumpWidget(screen(h, const ItemsScreen(clientTxnId: 'a'), rows: [tagged], brightness: brightness));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/what_did_you_get_$theme.png'));
    });

    testWidgets('settings ($theme)', (tester) async {
      await signedIn(tester);
      // Debug-only rows are part of this image because tests run in debug mode.
      setSurface(tester, const Size(412, 1360));
      await tester.pumpWidget(screen(h, const SettingsScreen(), brightness: brightness));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_$theme.png'));
    });
  }
}
