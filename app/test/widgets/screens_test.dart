import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/capture/transaction_source.dart';
import 'package:forreal/core/providers.dart';
import 'package:forreal/core/widgets.dart';
import 'package:forreal/data/models.dart';
import 'package:forreal/features/auth/welcome_screen.dart';
import 'package:forreal/features/home/coming_soon_screen.dart';
import 'package:forreal/features/home/home_screen.dart';
import 'package:forreal/features/items/items_screen.dart';
import 'package:forreal/features/onboarding/onboarding_screen.dart';
import 'package:forreal/features/payee/payee_screen.dart';
import 'package:forreal/features/settings/settings_screen.dart';
import 'package:forreal/features/transaction/transaction_detail_screen.dart';
import 'package:forreal/features/ui_providers.dart';

import '../support/fake_api.dart';
import '../support/fakes.dart';
import '../support/harness.dart';
import 'support.dart';

void main() {
  late Harness h;

  setUp(() {
    h = Harness();
    h.serveConsents();
    h.serveTemplates();
  });
  tearDown(() => h.dispose());

  /// A tall phone, so lazily built lists show all their rows.
  Widget app(WidgetTester tester, Widget child,
      {List rows = const [], SmsPermission sms = SmsPermission.granted, Size size = const Size(412, 2400)}) {
    setSurface(tester, size);
    return screen(h, child, rows: rows.cast(), sms: sms);
  }

  Future<void> signedIn({bool consent = true}) async {
    h.api.reply('PUT', 'me/device/', {'device_id': 'x'});
    await h.session.onSignedIn(AuthSession.fromJson({
      'access': 'access-1',
      'refresh': 'refresh-1',
      'is_new_user': true,
      'user': {'id': 'u', 'phone': '+919876543210', 'display_name': ''},
    }));
    if (consent) await h.session.setConsent(Purpose.privateAnalytics, true);
  }

  /// Taps something whose action talks to the fake backend, and lets it finish.
  Future<void> tapAsync(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
  }

  group('welcome', () {
    testWidgets('says what the app is and leads to sign-in', (tester) async {
      await tester.pumpWidget(app(tester, const WelcomeScreen(), size: const Size(412, 892)));
      await tester.pumpAndSettle();
      expect(find.text('Where people actually pay.'), findsOneWidget);
      expect(find.textContaining('A payment can’t'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Your name stays hidden. Always your call.'), findsOneWidget);
      // Dark in both themes.
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, AppColors.light.ink);
    });
  });

  group('home', () {
    testWidgets('each payment shows payee or shop, amount, time and a clear state', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(), rows: designRows()));
      await tester.pumpAndSettle();

      expect(find.text('RAMESH KUMAR'), findsOneWidget, reason: 'whitespace collapsed for display');
      expect(find.text('₹300'), findsOneWidget);
      expect(find.text('6:42 pm'), findsOneWidget);
      expect(find.text('Shop or person?'), findsOneWidget);
      expect(find.text('Sharma Tea Stall'), findsOneWidget);
      expect(find.text('What did you get?'), findsOneWidget);
      expect(find.text('Cake · Bread'), findsOneWidget);
      expect(find.text('Ride, guessed'), findsOneWidget, reason: 'an inferred item is visibly a guess');
      expect(find.text('Person · private'), findsOneWidget);
      expect(find.text('₹1,200'), findsOneWidget);
    });

    testWidgets('rows are grouped by day and the week is summed from exact local amounts', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(), rows: designRows()));
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('₹2,061'), findsOneWidget);
      expect(find.text('5 payments'), findsOneWidget);
      expect(find.text('3 payments need a quick answer'), findsOneWidget);
    });

    testWidgets('a restored payment shows its range, a waiting one its upload mark', (tester) async {
      await tester.runAsync(signedIn);
      final rows = [
        row('restored', amount: null, payee: 'OLD PAYEE'),
        row('waiting', syncState: 'pending', payee: 'NEW PAYEE', at: DateTime(2026, 10, 7, 9)),
      ];
      await tester.pumpWidget(app(tester, const HomeScreen(), rows: rows));
      await tester.pumpAndSettle();
      expect(find.text('₹200 to 500'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Waiting to upload')), findsOneWidget);
    });

    testWidgets('filter chips narrow the list', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(), rows: designRows()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Needs you · 3'));
      await tester.pumpAndSettle();
      expect(find.text('Modern Bakery'), findsNothing);
      expect(find.text('Rina Devi'), findsNothing);
      expect(find.text('RAMESH KUMAR'), findsOneWidget);
      expect(find.text('Rapido'), findsOneWidget, reason: 'a guess still wants a quick answer');

      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      expect(find.text('Rina Devi'), findsOneWidget);
      expect(find.text('RAMESH KUMAR'), findsNothing);

      await tester.tap(find.text('Shops'));
      await tester.pumpAndSettle();
      expect(find.text('Modern Bakery'), findsOneWidget);
      expect(find.text('Rina Devi'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentRow), findsNWidgets(5));
    });

    testWidgets('"needs a quick answer" filters the list', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(), rows: designRows()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 payments need a quick answer'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentRow), findsNWidgets(3));
    });

    testWidgets('the summary notification opens the list already filtered', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(untaggedOnly: true), rows: designRows()));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentRow), findsNWidgets(3));
      expect(find.text('Modern Bakery'), findsNothing);
    });

    testWidgets('"Capture is off" appears when SMS access is denied, and tapping it asks again', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(), rows: designRows(), sms: SmsPermission.denied));
      await tester.pumpAndSettle();
      expect(find.text('Capture is off'), findsOneWidget);
      expect(find.text('Allow SMS access so payments show up on their own.'), findsOneWidget);
      expect(find.text('RAMESH KUMAR'), findsOneWidget, reason: 'the app still works');

      h.source.promptAnswer = SmsPermission.granted;
      await tapAsync(tester, find.text('Capture is off'));
      expect(h.source.permissionRequests, 1);
      expect(find.text('Capture is off'), findsNothing, reason: 'granted now');
    });

    testWidgets('after repeated refusals the banner opens app settings', (tester) async {
      await tester.runAsync(signedIn);
      var opened = 0;
      setSurface(tester, const Size(412, 2400));
      h.source.permission = SmsPermission.deniedForever;
      final container = ProviderContainer(parent: h.container, overrides: [
        openAppSettingsProvider.overrideWithValue(() async => opened++),
        transactionsProvider.overrideWith((ref) => Stream.value(designRows())),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: appTheme(Brightness.light), home: const HomeScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('in app settings'), findsOneWidget);
      await tapAsync(tester, find.text('Capture is off'));
      expect(opened, 1);
      expect(h.source.permissionRequests, 0, reason: 'Android would not show its prompt again');
    });

    testWidgets('"Capture is off" also appears when the required consent is missing', (tester) async {
      await tester.runAsync(() => signedIn(consent: false));
      await tester.pumpWidget(app(tester, const HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Capture is off'), findsOneWidget);
      expect(find.textContaining('Turn on payment messages'), findsOneWidget);
    });

    testWidgets('empty: no banner when all is well, and a friendly empty state', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(), size: const Size(412, 892)));
      await tester.pumpAndSettle();
      expect(find.text('Capture is off'), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Pay any shop by UPI and it lands here within a minute.'), findsOneWidget);
    });

    testWidgets('loading shows skeleton rows, not a spinner on a blank page', (tester) async {
      await tester.runAsync(signedIn);
      setSurface(tester, const Size(412, 892));
      final container = ProviderContainer(parent: h.container, overrides: [
        transactionsProvider.overrideWith((ref) => const Stream.empty()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: appTheme(Brightness.light), home: const HomeScreen()),
      ));
      await tester.pump();
      expect(find.byType(SkeletonRow), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('has the four tabs with Payments active', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const HomeScreen(), size: const Size(412, 892)));
      await tester.pumpAndSettle();
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.active, AppTab.payments);
      for (final label in ['Discover', 'Insights', 'You']) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('coming soon tabs', () {
    testWidgets('Discover and Insights say what they will do and offer nothing to tap', (tester) async {
      await tester.pumpWidget(app(tester, const ComingSoonScreen.discover(), size: const Size(412, 892)));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.textContaining('ranked by real payments'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);

      await tester.pumpWidget(app(tester, const ComingSoonScreen.insights(), size: const Size(412, 892)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Where your own money goes'), findsOneWidget);
      expect(tester.widget<AppBottomNav>(find.byType(AppBottomNav)).active, AppTab.insights);
    });
  });

  group('payment detail', () {
    testWidgets('an unknown payee offers "Shop or person?"', (tester) async {
      await tester.pumpWidget(app(tester, const TransactionDetailScreen(clientTxnId: 'a'), rows: [row('a')]));
      await tester.pumpAndSettle();
      expect(find.text('₹300'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Shop or person?'), findsOneWidget);
      expect(find.text('Not until it is a shop'), findsOneWidget);
      expect(find.text('Stays on this phone'), findsOneWidget);
    });

    testWidgets('a tagged shop payment shows green chips and the ways to correct it', (tester) async {
      final r = row('a', kind: 'merchant', merchant: teaStall, ask: null, amount: 55, items: [
        guess('Tea', inferred: false, quantity: 2),
        guess('Samosa', inferred: false, id: 4),
      ]);
      await tester.pumpWidget(app(tester, const TransactionDetailScreen(clientTxnId: 'a'), rows: [r]));
      await tester.pumpAndSettle();

      expect(find.text('Sharma Tea Stall'), findsOneWidget);
      expect(find.text('Tea × 2'), findsOneWidget);
      final chips = tester.widgetList<AppChip>(find.byType(AppChip)).toList();
      expect(chips.every((c) => c.variant == AppChipVariant.real), isTrue);
      expect(find.text('Your bank calls them'), findsOneWidget);
      expect(find.text('RAMESH KUMAR'), findsOneWidget);
      expect(find.text('Bank SMS'), findsOneWidget);
      expect(find.text('Edit what you got'), findsOneWidget);
      expect(find.text('Different shop'), findsOneWidget);
      expect(find.text('Not a shop'), findsOneWidget);
    });

    testWidgets('a guess is never green: dashed chip, labelled as a guess', (tester) async {
      final r = row('a', kind: 'merchant', merchant: teaStall, ask: 'items', items: [guess('Tea')]);
      await tester.pumpWidget(app(tester, const TransactionDetailScreen(clientTxnId: 'a'), rows: [r]));
      await tester.pumpAndSettle();
      expect(tester.widget<AppChip>(find.byType(AppChip)).variant, AppChipVariant.guess);
      expect(find.byType(DashedBorder), findsOneWidget);
      expect(find.bySemanticsLabel('Tea, guessed'), findsOneWidget);
    });

    testWidgets('"Counts in rankings" follows the community consent', (tester) async {
      await tester.runAsync(signedIn);
      final r = row('a', kind: 'merchant', merchant: teaStall, ask: null, items: [guess('Tea', inferred: false)]);
      await tester.pumpWidget(app(tester, const TransactionDetailScreen(clientTxnId: 'a'), rows: [r]));
      await tester.pumpAndSettle();
      expect(find.text('No, rankings are off'), findsOneWidget);

      await tester.runAsync(() => h.session.setConsent(Purpose.communityRankings, true));
      await tester.pumpAndSettle();
      expect(find.text('Yes, with no name'), findsOneWidget);
    });

    testWidgets('a person can be corrected to a shop', (tester) async {
      await tester.pumpWidget(
          app(tester, const TransactionDetailScreen(clientTxnId: 'a'), rows: [row('a', kind: 'person', ask: null)]));
      await tester.pumpAndSettle();
      expect(find.text('This is actually a shop'), findsOneWidget);
      expect(find.text('No, stays private'), findsOneWidget);
    });

    testWidgets('a row the server refused shows why and can be retried', (tester) async {
      final r = row('a', syncState: 'failed', error: 'occurred_on: Date is in the future.');
      await tester.pumpWidget(app(tester, const TransactionDetailScreen(clientTxnId: 'a'), rows: [r]));
      await tester.pumpAndSettle();
      expect(find.textContaining('Date is in the future.'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Try again'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Shop or person?'), findsNothing, reason: 'no tagging before upload');
    });
  });

  group('payee', () {
    void serve() {
      h.api.reply('GET', 'payees/7/suggestions/', {
        'payee': {'id': 7, 'name': 'RAMESH  KUMAR'},
        'crowd': [teaStall],
      });
      h.api.reply('GET', 'categories/', {
        'categories': [
          {'slug': 'tea-stall', 'name': 'Tea stall'},
          {'slug': 'bakery', 'name': 'Bakery'},
        ]
      });
      h.api.on('POST', 'payees/7/resolve/', (r) {
        return FakeResponse.ok({
          'payee': {'id': 7, 'name': 'RAMESH  KUMAR'},
          'kind': r.json['kind'],
          'merchant': r.json['kind'] == 'person' ? null : teaStall,
        });
      });
      h.api.reply('GET', 'transactions/s-a/', serverTxn('a', id: 's-a', kind: 'merchant', merchant: teaStall));
    }

    testWidgets('asks "shop or person" with the payment facts', (tester) async {
      serve();
      await tester.pumpWidget(app(tester, const PayeeScreen(clientTxnId: 'a'), rows: [row('a'), row('b')]));
      await tester.pumpAndSettle();
      expect(find.text('New payee'), findsOneWidget);
      expect(find.text('YOU PAID'), findsOneWidget);
      expect(find.text('RAMESH KUMAR'), findsOneWidget);
      expect(find.text('₹300 · today, 6:42 pm · 2 payments so far'), findsOneWidget);
      expect(find.text('Is this a shop or a person?'), findsOneWidget);
      expect(find.textContaining('Applies to every payment to this name'), findsOneWidget);
    });

    testWidgets('a person: choose it, continue, and the payee is resolved', (tester) async {
      serve();
      await tester.runAsync(() async {
        await h.store.insertParsed(parsed('a'), fromHistory: false);
        await h.store.applyIngestResult('a', IngestResult.fromJson(ingestResult(serverTxn('a'))));
      });
      await tester.pumpWidget(app(tester, const PayeeScreen(clientTxnId: 'a'), rows: [row('a')]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A person'));
      await tester.pumpAndSettle();
      await tapAsync(tester, find.text('Continue'));
      expect(h.api.to('POST', 'payees/7/resolve/').single.json, {'kind': 'person'});
    });

    testWidgets('a shop: crowd suggestion, search and "Add a new shop"', (tester) async {
      serve();
      await tester.pumpWidget(app(tester, const PayeeScreen(clientTxnId: 'a'), rows: [row('a')]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Which shop is it?'), findsOneWidget);
      expect(find.text('PEOPLE NEARBY SAY'), findsOneWidget);
      expect(find.text('Sharma Tea Stall'), findsOneWidget);
      expect(find.text('Tea stall'), findsOneWidget, reason: 'category shown by name');
      expect(find.text('That’s it'), findsOneWidget);
      expect(find.text('Search shops near you'), findsOneWidget);
      expect(h.api.to('GET', 'payees/7/suggestions/').single.query, isEmpty,
          reason: 'the payment is old, so no location is sent');

      await tester.tap(find.text('Add a new shop'));
      await tester.pumpAndSettle();
      expect(find.text('Add a shop'), findsOneWidget);
      expect(find.text('Shop name'), findsOneWidget);
      expect(find.text('Your bank calls them RAMESH KUMAR'), findsOneWidget);
      expect(find.text('What kind of place?'), findsOneWidget);
      expect(find.text('Bakery'), findsOneWidget);
      expect(find.text('Online or no fixed place'), findsOneWidget);
      expect(find.text('Near where you are now'), findsNothing, reason: 'no location for an old payment');
    });

    testWidgets('adding a shop sends name, category and the online flag', (tester) async {
      serve();
      await tester.runAsync(() async {
        await h.store.insertParsed(parsed('a'), fromHistory: false);
        await h.store.applyIngestResult('a', IngestResult.fromJson(ingestResult(serverTxn('a'))));
      });
      await tester.pumpWidget(app(tester, const PayeeScreen(clientTxnId: 'a'), rows: [row('a')]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a new shop'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sharma Tea Stall');
      await tester.tap(find.text('Tea stall'));
      await tester.pumpAndSettle();
      await tapAsync(tester, find.text('Save shop'));
      expect(h.api.to('POST', 'payees/7/resolve/').single.json, {
        'kind': 'merchant',
        'new_merchant': {'name': 'Sharma Tea Stall', 'category': 'tea-stall', 'is_online': false},
      });
    });

    testWidgets('back steps through the stages', (tester) async {
      serve();
      await tester.pumpWidget(app(tester, const PayeeScreen(clientTxnId: 'a'), rows: [row('a')]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Is this a shop or a person?'), findsOneWidget);
    });
  });

  group('items', () {
    final tagged = row('a', kind: 'merchant', merchant: teaStall, items: [guess('Tea')], ask: 'items', amount: 55);

    void serveChips() {
      h.api.reply('GET', 'items/', {
        'items': [
          {'id': 3, 'name': 'Tea', 'category': 'tea-stall'},
          {'id': 4, 'name': 'Samosa', 'category': 'tea-stall'},
        ]
      });
    }

    AppChip chip(WidgetTester tester, String label) => tester.widget<AppChip>(find.widgetWithText(AppChip, label));

    testWidgets('the guess is announced, preselected, and can be confirmed in one tap', (tester) async {
      serveChips();
      await tester.pumpWidget(app(tester, const ItemsScreen(clientTxnId: 'a'), rows: [tagged]));
      await tester.pumpAndSettle();

      expect(find.text('Our guess: Tea'), findsOneWidget);
      expect(find.text('PICK EVERYTHING YOU GOT'), findsOneWidget);
      expect(chip(tester, 'Tea').variant, AppChipVariant.selected);
      expect(chip(tester, 'Samosa').variant, AppChipVariant.normal);
      expect(find.text('Yes, correct'), findsOneWidget);
      expect(find.text('₹55'), findsOneWidget);
      expect(h.api.to('GET', 'items/').single.query, {'category': 'tea-stall'});
    });

    testWidgets('changing the selection or a quantity turns it into Save', (tester) async {
      serveChips();
      await tester.pumpWidget(app(tester, const ItemsScreen(clientTxnId: 'a'), rows: [tagged]));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppChip, 'Samosa'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Yes, correct'), findsNothing);
      expect(find.text('HOW MANY?'), findsOneWidget);

      // Quantity stepper: default 1, raise Samosa to 2.
      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byTooltip('Fewer').last);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
    });

    testWidgets('"Add your own" adds free text as a selected chip', (tester) async {
      serveChips();
      await tester.pumpWidget(app(tester, const ItemsScreen(clientTxnId: 'a'), rows: [tagged]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your own'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bun maska');
      await tester.tap(find.widgetWithText(AppButton, 'Add'));
      await tester.pumpAndSettle();
      expect(chip(tester, 'bun maska').variant, AppChipVariant.selected);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('a shop payment without stored guesses preselects the server suggestions', (tester) async {
      serveChips();
      h.api.reply('GET', 'transactions/s-a/suggestions/', {
        'suggestions': [
          {
            'item': {'id': 4, 'name': 'Samosa', 'category': 'tea-stall'},
            'quantity': 2,
            'origin': 'ai_own_history',
            'confidence': 0.8
          }
        ],
        'should_prompt': true,
      });
      final untagged = row('a', kind: 'merchant', merchant: teaStall, ask: 'items');
      await tester.pumpWidget(app(tester, const ItemsScreen(clientTxnId: 'a'), rows: [untagged]));
      await tester.pumpAndSettle();

      expect(chip(tester, 'Samosa').variant, AppChipVariant.selected);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Our guess: Samosa × 2, from your last visits'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget, reason: 'nothing is stored yet, so there is nothing to confirm');
    });

    testWidgets('"This isn’t a shop" asks first, then marks the payee as a person', (tester) async {
      serveChips();
      h.api.reply('POST', 'payees/7/resolve/', {
        'payee': {'id': 7, 'name': 'X'},
        'kind': 'person',
        'merchant': null,
      });
      await tester.pumpWidget(app(tester, const ItemsScreen(clientTxnId: 'a'), rows: [tagged]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This isn’t a shop'));
      await tester.pumpAndSettle();
      expect(find.text('Not a shop?'), findsOneWidget);
      expect(h.api.to('POST', 'payees/7/resolve/'), isEmpty);
      await tapAsync(tester, find.text('Yes, it’s a person'));
      expect(h.api.to('POST', 'payees/7/resolve/').single.json, {'kind': 'person'});
    });

    testWidgets('a payment to a person cannot be tagged', (tester) async {
      await tester.pumpWidget(
          app(tester, const ItemsScreen(clientTxnId: 'a'), rows: [row('a', kind: 'person', ask: null)]));
      await tester.pumpAndSettle();
      expect(find.textContaining('private and are not tagged'), findsOneWidget);
    });
  });

  group('onboarding', () {
    Future<void> start(WidgetTester tester, {bool consent = false}) async {
      await tester.runAsync(() => signedIn(consent: consent));
      await tester.pumpWidget(app(tester, const OnboardingScreen(), size: const Size(412, 1400)));
      await tester.pumpAndSettle();
    }

    testWidgets('step 1 is required: "Not now" does not get past it', (tester) async {
      await start(tester);
      expect(find.text('1 of 5'), findsOneWidget);
      expect(find.text('Let ForReal read your payment messages'), findsOneWidget);
      expect(find.text('Only bank payment alerts'), findsOneWidget);
      expect(find.text('Never read'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('ForReal needs this to work'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 5'), findsOneWidget, reason: 'still on the required step');
      expect(h.serverConsents['private_analytics'], isFalse);
      expect(h.source.captureEnabled, isFalse);
    });

    testWidgets('step 1: allowing grants the consent, asks Android for SMS access, and moves on', (tester) async {
      await start(tester);
      await tapAsync(tester, find.text('Allow and continue'));

      expect(h.serverConsents['private_analytics'], isTrue);
      expect(h.source.captureEnabled, isTrue);
      expect(h.source.permissionRequests, 1);
      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('Count me in, anonymously'), findsOneWidget);
    });

    testWidgets('step 1: the full notice is one tap away', (tester) async {
      await start(tester);
      await tester.tap(find.text('Read the full notice'));
      await tester.pumpAndSettle();
      expect(find.text('Track your own spending'), findsOneWidget);
      expect(find.textContaining('exact amount stay on this phone'), findsOneWidget);
    });

    testWidgets('step 2: rankings is off by default, nothing is granted until Continue, insights is hidden',
        (tester) async {
      await start(tester, consent: true);
      await tapAsync(tester, find.text('Allow and continue'));

      final toggles = tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();
      expect(toggles, hasLength(1), reason: 'the merchant-insights toggle is behind a feature flag');
      expect(toggles.single.value, isFalse);
      expect(find.text('Insights for shops'), findsNothing);
      expect(find.text('Payments to people are never counted or shared.'), findsOneWidget);

      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(h.serverConsents['community_rankings'], isFalse);
      await tapAsync(tester, find.text('Continue'));
      expect(h.serverConsents['community_rankings'], isTrue);
      expect(h.serverConsents['merchant_insights'], isFalse);
      expect(find.text('3 of 5'), findsOneWidget);
    });

    testWidgets('skipped steps still advance, in the designed order', (tester) async {
      await start(tester, consent: true);
      await tapAsync(tester, find.text('Allow and continue'));
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('3 of 5'), findsOneWidget);
      expect(find.text('Find the shop you just paid'), findsOneWidget);
      expect(find.text('Sent rounded to OpenStreetMap to name the area'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('4 of 5'), findsOneWidget);
      expect(find.text('One tap after you pay'), findsOneWidget);
      expect(find.text('Paid ₹55 at Sharma Tea Stall'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('5 of 5'), findsOneWidget);
      expect(find.text('Bring in past payments?'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(h.serverConsents['community_rankings'], isFalse);
      expect(h.serverConsents['location'], isFalse);

      // Back goes one step back.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('4 of 5'), findsOneWidget);
    });

    testWidgets('the last step finishes setup', (tester) async {
      await start(tester, consent: true);
      await tapAsync(tester, find.text('Allow and continue'));
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start fresh'));
      await tester.pumpAndSettle();
      await tapAsync(tester, find.text('Finish setup'));
      expect(h.state.onboardingDone, isTrue);
    });

    testWidgets('someone returning after a withdrawal only sees the required step', (tester) async {
      await tester.runAsync(() async {
        await signedIn(consent: false);
        await h.session.completeOnboarding();
      });
      await tester.pumpWidget(app(tester, const OnboardingScreen(), size: const Size(412, 1400)));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOneWidget);
    });
  });

  group('you: privacy and data', () {
    testWidgets('shows the toggles, data actions and the two ways out', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('+91 98••• ••210'), findsOneWidget, reason: 'the number is masked');
      expect(find.text('WHAT YOU SHARE'), findsOneWidget);
      for (final title in ['Payment messages', 'Community rankings', 'Show my name', 'Location']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Insights for shops'), findsNothing, reason: 'hidden behind a feature flag');
      expect(find.text('Needs "Community rankings"'), findsOneWidget, reason: 'show my name depends on rankings');
      expect(find.text('Import past payments'), findsOneWidget);
      expect(find.text('Export my data'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account and all data'), findsOneWidget);
      expect(find.textContaining('© OpenStreetMap contributors'), findsOneWidget);
      expect(tester.widget<AppBottomNav>(find.byType(AppBottomNav)).active, AppTab.you);

      final toggles = tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();
      expect([for (final t in toggles) t.value], [true, false, false, false]);
    });

    testWidgets('switching a consent on shows its notice and then calls the consent API', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const SettingsScreen()));
      await tester.pumpAndSettle();
      final before = h.api.to('POST', 'consents/').length;

      await tester.tap(find.byType(AppToggle).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Contribute to community rankings'), findsOneWidget);
      expect(h.api.to('POST', 'consents/'), hasLength(before), reason: 'nothing is sent before agreeing');

      await tapAsync(tester, find.text('I agree'));
      expect(h.api.to('POST', 'consents/').last.json['purpose'], 'community_rankings');
      expect(h.api.to('POST', 'consents/').last.json['granted'], isTrue);
      expect(tester.widgetList<AppToggle>(find.byType(AppToggle)).elementAt(1).value, isTrue);
    });

    testWidgets('switching payment messages off warns first', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppToggle).first);
      await tester.pumpAndSettle();
      expect(find.text('Switch off "Payment messages"?'), findsOneWidget);
      expect(find.textContaining('delete all your payments'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.serverConsents['private_analytics'], isTrue);
    });

    testWidgets('a consent row opens its full notice', (tester) async {
      await tester.runAsync(signedIn);
      await tester.pumpWidget(app(tester, const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Location'));
      await tester.pumpAndSettle();
      expect(find.text('Use approximate location'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsWidgets);
    });
  });
}
