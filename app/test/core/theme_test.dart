import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forreal/core/format.dart';
import 'package:forreal/core/theme/app_theme.dart';

void main() {
  group('colour tokens', () {
    test('light and dark values match the design', () {
      const l = AppColors.light;
      const d = AppColors.dark;
      expect([l.bg, l.surface, l.surfaceAlt], const [Color(0xFFFAF6EF), Color(0xFFFFFFFF), Color(0xFFF1EBE0)]);
      expect([l.ink, l.inkMuted, l.inkFaint, l.line],
          const [Color(0xFF16130F), Color(0xFF6B645A), Color(0xFFA59D90), Color(0xFFE4DCCD)]);
      expect([l.brand, l.onBrand, l.brandSoft], const [Color(0xFFFFB000), Color(0xFF16130F), Color(0xFFFFF1CC)]);
      expect([l.real, l.realSoft, l.onInk], const [Color(0xFF0E9F6E), Color(0xFFDDF5EA), Color(0xFFFAF6EF)]);
      expect([l.danger, l.dangerSoft], const [Color(0xFFD6402B), Color(0xFFFBE3DE)]);

      expect([d.bg, d.surface, d.surfaceAlt], const [Color(0xFF121110), Color(0xFF1C1A18), Color(0xFF262320)]);
      expect([d.ink, d.inkMuted, d.inkFaint, d.line],
          const [Color(0xFFF6F1E8), Color(0xFFA79F93), Color(0xFF6F685E), Color(0xFF34302B)]);
      expect([d.brand, d.onBrand, d.brandSoft], const [Color(0xFFFFB000), Color(0xFF16130F), Color(0xFF3A2E0C)]);
      expect([d.real, d.realSoft, d.onInk], const [Color(0xFF34D399), Color(0xFF0F2E24), Color(0xFF121110)]);
      expect([d.danger, d.dangerSoft], const [Color(0xFFF0705C), Color(0xFF3A1711)]);
    });

    test('the Material colour scheme is built from the tokens', () {
      for (final brightness in Brightness.values) {
        final theme = appTheme(brightness);
        final c = AppColors.of(brightness);
        expect(theme.extension<AppColors>(), c);
        expect(theme.colorScheme.primary, c.ink);
        expect(theme.colorScheme.onPrimary, c.onInk);
        expect(theme.colorScheme.secondary, c.brand);
        expect(theme.colorScheme.error, c.danger);
        expect(theme.scaffoldBackgroundColor, c.bg);
      }
    });

    test('lerp interpolates between themes', () {
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid.brand, AppColors.light.brand);
      expect(mid.bg, isNot(AppColors.light.bg));
    });
  });

  group('text contrast is at least 4.5:1', () {
    for (final (name, c) in [('light', AppColors.light), ('dark', AppColors.dark)]) {
      final pairs = <String, (Color, Color)>{
        'ink on bg': (c.ink, c.bg),
        'ink on surface': (c.ink, c.surface),
        'inkMuted on bg': (c.inkMuted, c.bg),
        'inkMuted on surface': (c.inkMuted, c.surface),
        'inkMuted on surfaceAlt': (c.inkMuted, c.surfaceAlt),
        'onBrand on brand': (c.onBrand, c.brand),
        'ink on brandSoft': (c.ink, c.brandSoft),
        'onInk on ink': (c.onInk, c.ink),
        'ink on dangerSoft': (c.ink, c.dangerSoft),
      };
      for (final entry in pairs.entries) {
        test('$name: ${entry.key}', () {
          final ratio = contrastRatio(entry.value.$1, entry.value.$2);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '${entry.key} is ${ratio.toStringAsFixed(2)}:1');
        });
      }
    }

    test('known shortfalls in the design tokens are recorded, not hidden', () {
      // These pairs come straight from the design and are below 4.5:1 in the light
      // theme. They are reported to design; the numbers are pinned here so a token
      // change that fixes (or worsens) them is noticed.
      const l = AppColors.light;
      expect(contrastRatio(l.real, l.realSoft), closeTo(2.95, 0.1), reason: 'green chip text');
      expect(contrastRatio(l.danger, l.dangerSoft), closeTo(3.6, 0.15), reason: 'danger button text');
      expect(contrastRatio(l.inkFaint, l.surface), closeTo(2.7, 0.15), reason: 'placeholder text');
    });
  });

  group('type scale', () {
    test('sizes, line heights, weights and tracking match the design', () {
      void check(TextStyle s, double size, double line, FontWeight weight, double tracking) {
        expect(s.fontSize, size);
        expect(s.height! * size, closeTo(line, 0.001));
        expect(s.fontWeight, weight);
        expect(s.letterSpacing, closeTo(tracking, 0.001));
      }

      check(AppText.displayXL, 40, 44, FontWeight.w800, -0.6);
      check(AppText.displayL, 30, 34, FontWeight.w800, -0.3);
      check(AppText.displayM, 24, 30, FontWeight.w700, -0.12);
      check(AppText.titleL, 20, 26, FontWeight.w700, -0.06);
      check(AppText.titleM, 17, 24, FontWeight.w600, 0);
      check(AppText.bodyL, 16, 24, FontWeight.w400, 0);
      check(AppText.bodyM, 14, 20, FontWeight.w400, 0);
      check(AppText.labelL, 15, 20, FontWeight.w600, 0);
      check(AppText.labelM, 13, 18, FontWeight.w600, 0);
      check(AppText.labelS, 12, 16, FontWeight.w500, 0);
      check(AppText.caption, 12, 16, FontWeight.w400, 0);
      check(AppText.overline, 11, 14, FontWeight.w700, 0.88);
    });

    test('display and titles are Bricolage Grotesque, the rest DM Sans', () {
      expect(AppText.displayXL.fontFamily, contains('BricolageGrotesque'));
      expect(AppText.titleL.fontFamily, contains('BricolageGrotesque'));
      expect(AppText.titleM.fontFamily, contains('DMSans'));
      expect(AppText.bodyM.fontFamily, contains('DMSans'));
    });
  });

  group('formatting', () {
    final now = DateTime(2026, 10, 7, 19);
    test('day labels', () {
      expect(dayLabel(DateTime(2026, 10, 7, 1), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 10, 6, 23), now: now), 'Yesterday');
      expect(dayLabel(DateTime(2026, 10, 3), now: now), 'Sat, 3 Oct');
      expect(dayLabel(DateTime(2025, 12, 31), now: now), '31 Dec 2025');
      expect(dayAndTime(DateTime(2026, 10, 7, 16, 10), now: now), 'Today, 4:10 pm');
    });

    test('phone masking and category labels', () {
      expect(maskPhone('+919876543210'), '+91 98••• ••210');
      expect(maskPhone('12'), '12');
      expect(categoryLabel('tea-stall'), 'Tea stall');
      expect(categoryLabel('fruits-vegetables'), 'Fruits vegetables');
      expect(categoryLabel(''), '');
    });
  });
}
