import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'support.dart';

void main() {
  group('AppButton', () {
    testWidgets('each variant uses its tokens', (tester) async {
      const c = AppColors.light;
      Future<(Color?, Color?)> colors(AppButtonVariant variant) async {
        await tester.pumpWidget(themed(AppButton(label: 'Go', variant: variant, onPressed: () {})));
        final material = tester.widget<Material>(
          find.descendant(of: find.byType(AppButton), matching: find.byType(Material)),
        );
        final text = tester.widget<Text>(find.text('Go'));
        return (material.color, text.style?.color);
      }

      expect(await colors(AppButtonVariant.primary), (c.ink, c.onInk));
      expect(await colors(AppButtonVariant.brand), (c.brand, c.onBrand));
      expect(await colors(AppButtonVariant.secondary), (Colors.transparent, c.ink));
      expect(await colors(AppButtonVariant.ghost), (Colors.transparent, c.inkMuted));
      expect(await colors(AppButtonVariant.danger), (c.dangerSoft, c.danger));
    });

    testWidgets('is 54 high with a 16 radius, and full width by default', (tester) async {
      await tester.pumpWidget(themed(AppButton(label: 'Go', onPressed: () {})));
      final size = tester.getSize(find.byType(AppButton));
      expect(size.height, 54);
      expect(size.width, greaterThan(300));
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(AppButton), matching: find.byType(Material)),
      );
      expect((material.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(16));
    });

    testWidgets('shows a spinner and ignores taps while its action runs', (tester) async {
      var calls = 0;
      await tester.pumpWidget(themed(AppButton(
        label: 'Save',
        onPressed: () async {
          calls++;
          await Future<void>.delayed(const Duration(seconds: 1));
        },
      )));
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(AppButton));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('disabled when there is no action, and says so to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themed(const AppButton(label: 'Save', onPressed: null)));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        matchesSemantics(label: 'Save', isButton: true, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('an error from the action is shown, not thrown', (tester) async {
      await tester.pumpWidget(themed(AppButton(label: 'Save', onPressed: () async => throw StateError('x'))));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    });
  });

  group('AppChip', () {
    testWidgets('default, selected, guess and real look different and mean different things', (tester) async {
      const c = AppColors.light;
      await tester.pumpWidget(themed(const Wrap(children: [
        AppChip(label: 'Plain'),
        AppChip(label: 'Picked', variant: AppChipVariant.selected),
        AppChip(label: 'Tea', variant: AppChipVariant.guess),
        AppChip(label: 'Samosa', variant: AppChipVariant.real),
      ])));
      Color? textColor(String label) => tester.widget<Text>(find.text(label)).style?.color;
      expect(textColor('Plain'), c.ink);
      expect(textColor('Picked'), c.onInk);
      expect(textColor('Tea'), c.inkMuted, reason: 'a guess is muted');
      expect(textColor('Samosa'), c.real, reason: 'green only for the real thing');
      // A guess: dashed outline and a spark. Real: a check.
      expect(find.byType(DashedBorder), findsOneWidget);
      expect(find.byIcon(LucideIcons.sparkle), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('the pill is 38 high inside a 48 touch target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(themed(AppChip(label: 'Tea', onTap: () => taps++)));
      expect(tester.getSize(find.byType(AppChip)).height, 48);
      final pill = find.descendant(of: find.byType(AppChip), matching: find.byType(Container)).first;
      expect(tester.getSize(pill).height, 38);
      await tester.tap(find.byType(AppChip));
      expect(taps, 1);
    });

    testWidgets('a guess is announced as a guess', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themed(const AppChip(label: 'Tea', variant: AppChipVariant.guess)));
      expect(find.bySemanticsLabel('Tea, guessed'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AppToggle', () {
    testWidgets('is green when on, flips on tap, and has a 48 touch target', (tester) async {
      var value = false;
      await tester.pumpWidget(themed(StatefulBuilder(
        builder: (context, setState) =>
            AppToggle(value: value, semanticLabel: 'Location', onChanged: (v) => setState(() => value = v)),
      )));
      Color track() =>
          (tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration).color!;
      expect(track(), AppColors.light.line);
      expect(tester.getSize(find.byType(AppToggle)), const Size(52, 48));
      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(track(), AppColors.light.real);
    });

    testWidgets('disabled toggles do nothing', (tester) async {
      await tester.pumpWidget(themed(const AppToggle(value: false, onChanged: null)));
      await tester.tap(find.byType(AppToggle));
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
    });
  });

  group('AppTextField', () {
    testWidgets('shows label, prefix, helper, and the error instead of the helper', (tester) async {
      await tester.pumpWidget(themed(const AppTextField(label: 'Shop name', prefix: '+91', helper: 'A hint')));
      expect(find.text('Shop name'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('A hint'), findsOneWidget);

      await tester.pumpWidget(themed(const AppTextField(label: 'Shop name', helper: 'A hint', errorText: 'Too short')));
      expect(find.text('Too short'), findsOneWidget);
      expect(find.text('A hint'), findsNothing);
    });

    testWidgets('the focused border is 1.5 px ink', (tester) async {
      final theme = appTheme(Brightness.light).inputDecorationTheme;
      final focused = theme.focusedBorder! as OutlineInputBorder;
      final enabled = theme.enabledBorder! as OutlineInputBorder;
      expect(focused.borderSide.width, 1.5);
      expect(focused.borderSide.color, AppColors.light.ink);
      expect(enabled.borderSide.width, 1);
      expect(enabled.borderSide.color, AppColors.light.line);
    });
  });

  group('AppCard', () {
    testWidgets('has no shadow; outlined is 1 px line, selected is 1.5 px ink', (tester) async {
      RoundedRectangleBorder shapeOf() =>
          tester.widget<Material>(find.descendant(of: find.byType(AppCard), matching: find.byType(Material))).shape!
              as RoundedRectangleBorder;
      await tester.pumpWidget(themed(const AppCard(outlined: true, child: Text('x'))));
      expect(shapeOf().side.width, 1);
      expect(shapeOf().side.color, AppColors.light.line);
      expect(
          tester.widget<Material>(find.descendant(of: find.byType(AppCard), matching: find.byType(Material))).elevation,
          0);

      await tester.pumpWidget(themed(const AppCard(outlined: true, selected: true, child: Text('x'))));
      expect(shapeOf().side.width, 1.5);
      expect(shapeOf().side.color, AppColors.light.ink);
    });
  });

  group('small pieces', () {
    testWidgets('SectionLabel is upper case', (tester) async {
      await tester.pumpWidget(themed(const SectionLabel('Your data')));
      expect(find.text('YOUR DATA'), findsOneWidget);
    });

    testWidgets('IconTile is a 64 px marigold tile', (tester) async {
      await tester.pumpWidget(themed(const IconTile(icon: LucideIcons.bell)));
      expect(tester.getSize(find.byType(IconTile)), const Size(64, 64));
      final box = tester.widget<Container>(find.descendant(of: find.byType(IconTile), matching: find.byType(Container)));
      expect((box.decoration! as BoxDecoration).color, AppColors.light.brand);
    });

    testWidgets('StepHeader shows progress, "n of 5" and a labelled back button', (tester) async {
      var back = 0;
      await tester.pumpWidget(themed(StepHeader(step: 3, onBack: () => back++)));
      expect(find.text('3 of 5'), findsOneWidget);
      final segments = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      expect(segments, hasLength(5));
      final filled = [for (final s in segments) (s.decoration! as BoxDecoration).color == AppColors.light.ink];
      expect(filled, [true, true, true, false, false]);
      await tester.tap(find.byTooltip('Back'));
      expect(back, 1);
    });

    testWidgets('StepHeader has no back button on the first step', (tester) async {
      await tester.pumpWidget(themed(const StepHeader(step: 1)));
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.text('1 of 5'), findsOneWidget);
    });

    testWidgets('InfoBanner: tinted by tone, with a chevron when it leads somewhere', (tester) async {
      var taps = 0;
      await tester.pumpWidget(themed(InfoBanner(
        icon: LucideIcons.messageSquare,
        tone: BannerTone.danger,
        title: 'Capture is off',
        text: 'Allow SMS access.',
        onTap: () => taps++,
      )));
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(InfoBanner), matching: find.byType(Material)),
      );
      expect(material.color, AppColors.light.dangerSoft);
      expect(tester.widget<Text>(find.text('Capture is off')).style?.color, AppColors.light.danger);
      expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
      await tester.tap(find.byType(InfoBanner));
      expect(taps, 1);

      await tester.pumpWidget(themed(const InfoBanner(icon: LucideIcons.shieldCheck, tone: BannerTone.real, text: 'Safe')));
      expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
      expect(tester.widget<Text>(find.text('Safe')).style?.color, AppColors.light.real);
    });

    testWidgets('RoundIconButton has a 48 px target and a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themed(RoundIconButton(icon: LucideIcons.pencil, label: 'Edit', onPressed: () {})));
      expect(tester.getSize(find.byType(InkResponse)), const Size(48, 48));
      expect(find.bySemanticsLabel('Edit'), findsOneWidget);
      handle.dispose();
    });
  });

  group('PaymentRow', () {
    Widget rowIn(PaymentRowState state, {String? detail}) => themed(
          PaymentRow(title: 'Sharma Tea Stall', state: state, detail: detail, amount: '₹55', time: 'Today', onTap: () {}),
        );

    testWidgets('needsShop: "?" on brandSoft and a marigold pill', (tester) async {
      await tester.pumpWidget(rowIn(PaymentRowState.needsShop));
      expect(find.text('?'), findsOneWidget);
      final pill = tester.widget<Container>(find.ancestor(of: find.text('Shop or person?'), matching: find.byType(Container)).first);
      expect((pill.decoration! as BoxDecoration).color, AppColors.light.brand);
    });

    testWidgets('needsItems: initial and a soft marigold pill', (tester) async {
      await tester.pumpWidget(rowIn(PaymentRowState.needsItems));
      expect(find.text('S'), findsOneWidget);
      final pill = tester.widget<Container>(find.ancestor(of: find.text('What did you get?'), matching: find.byType(Container)).first);
      expect((pill.decoration! as BoxDecoration).color, AppColors.light.brandSoft);
    });

    testWidgets('done: green check and the items', (tester) async {
      await tester.pumpWidget(rowIn(PaymentRowState.done, detail: 'Tea · Samosa'));
      expect(find.text('Tea · Samosa'), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(LucideIcons.check)).color, AppColors.light.real);
    });

    testWidgets('guessed: spark, muted, labelled "guessed", and not green', (tester) async {
      await tester.pumpWidget(rowIn(PaymentRowState.guessed, detail: 'Tea'));
      expect(find.text('Tea, guessed'), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(LucideIcons.sparkle)).color, AppColors.light.inkMuted);
      expect(find.byIcon(LucideIcons.check), findsNothing);
    });

    testWidgets('person: lock and "Person · private"', (tester) async {
      await tester.pumpWidget(rowIn(PaymentRowState.person));
      expect(find.text('Person · private'), findsOneWidget);
      expect(find.byIcon(LucideIcons.lock), findsOneWidget);
      expect(find.byIcon(LucideIcons.user), findsOneWidget);
    });

    testWidgets('reads as one sentence to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(rowIn(PaymentRowState.guessed, detail: 'Tea'));
      expect(find.bySemanticsLabel('Sharma Tea Stall, ₹55, Today. Tea, guessed'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a state change fades and slides briefly, then settles', (tester) async {
      await tester.pumpWidget(rowIn(PaymentRowState.needsItems));
      await tester.pumpWidget(rowIn(PaymentRowState.done, detail: 'Tea'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('What did you get?'), findsOneWidget, reason: 'the old state is still fading out');
      await tester.pumpAndSettle();
      expect(find.text('What did you get?'), findsNothing);
      expect(find.text('Tea'), findsOneWidget);
    });
  });

  group('AppBottomNav', () {
    testWidgets('four tabs; the active one has the marigold pill; tapping selects', (tester) async {
      AppTab? picked;
      await tester.pumpWidget(MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(bottomNavigationBar: AppBottomNav(active: AppTab.payments, onSelect: (t) => picked = t)),
      ));
      for (final label in ['Payments', 'Discover', 'Insights', 'You']) {
        expect(find.text(label), findsOneWidget);
      }
      final pills = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      final brand = [for (final p in pills) (p.decoration! as BoxDecoration).color == AppColors.light.brand];
      expect(brand, [true, false, false, false]);
      await tester.tap(find.text('You'));
      expect(picked, AppTab.you);
      // Every tab is at least 48 px in both directions.
      for (final target in tester.widgetList<InkResponse>(find.byType(InkResponse))) {
        final size = tester.getSize(find.byWidget(target));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });
  });
}
