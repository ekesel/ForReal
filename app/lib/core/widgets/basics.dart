import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Overline: small, bold, upper case. Introduces a group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: AppText.overline.copyWith(color: color ?? context.colors.inkMuted),
      ),
    );
  }
}

/// The 64 px marigold tile that opens each onboarding step.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = 64, this.muted = false});

  final IconData icon;
  final double size;

  /// Neutral tile, for "coming soon" and empty states.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: muted ? c.surfaceAlt : c.brand,
          borderRadius: BorderRadius.circular(size * 0.3125),
        ),
        child: Icon(icon, size: size * 0.47, color: muted ? c.inkMuted : c.onBrand),
      ),
    );
  }
}

/// The 46 px rounded square that leads a row: an initial, "?" or an icon.
class AvatarBox extends StatelessWidget {
  const AvatarBox({super.key, this.letter, this.icon, this.color, this.foreground, this.size = 46});

  final String? letter;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = foreground ?? c.ink;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? c.surfaceAlt,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: icon != null
            ? Icon(icon, size: size * 0.43, color: fg)
            : Text(
                letter ?? '',
                textScaler: TextScaler.noScaling,
                style: (size > 60 ? AppText.displayL : AppText.titleL).copyWith(color: fg),
              ),
      ),
    );
  }
}

/// First letter of a name for an avatar, upper case.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

/// A 40 px circular icon button in a 48 px touch target. Always labelled.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;

  /// Read by screen readers and shown as a tooltip.
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onPressed,
          radius: 28,
          child: SizedBox(
            width: AppSize.touch,
            height: AppSize.touch,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line),
                ),
                child: Icon(icon, size: 20, color: c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back button and title at the top of a pushed screen.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, this.title, required this.onBack, this.trailing});

  final String? title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pull the 48 px target left so the 40 px circle sits on the screen padding.
        Transform.translate(
          offset: const Offset(-4, 0),
          child: RoundIconButton(icon: LucideIcons.chevronLeft, label: 'Back', onPressed: onBack),
        ),
        const SizedBox(width: AppSpace.x4),
        Expanded(
          child: title == null
              ? const SizedBox.shrink()
              : Text(
                  title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleL.copyWith(color: context.colors.ink),
                ),
        ),
        if (trailing != null) Transform.translate(offset: const Offset(4, 0), child: trailing),
      ],
    );
  }
}

/// Back button, five progress segments and "n of 5" for onboarding.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, this.total = 5, this.onBack});

  /// 1-based.
  final int step;
  final int total;

  /// Null hides the back button (first step).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Step $step of $total',
      child: Row(
        children: [
          if (onBack != null)
            Transform.translate(
              offset: const Offset(-4, 0),
              child: RoundIconButton(icon: LucideIcons.chevronLeft, label: 'Back', onPressed: onBack),
            )
          else
            const SizedBox(height: AppSize.touch),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: onBack == null ? 0 : AppSpace.x8, right: AppSpace.x12),
              child: Row(
                children: [
                  for (var i = 1; i <= total; i++) ...[
                    if (i > 1) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppMotion.quick,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step ? c.ink : c.line,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ExcludeSemantics(
            child: Text('$step of $total', style: AppText.labelS.copyWith(color: c.inkMuted)),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { real, brand, danger, neutral }

/// A soft tinted row with an icon: a reassurance, a hint, or a warning.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.title,
    this.tone = BannerTone.neutral,
    this.onTap,
  });

  final IconData icon;
  final String text;

  /// Optional heading above [text] (used by the "Capture is off" banner).
  final String? title;
  final BannerTone tone;

  /// Makes the banner a button and shows a chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fill, Color accent, Color body) = switch (tone) {
      BannerTone.real => (c.realSoft, c.real, c.real),
      BannerTone.brand => (c.brandSoft, c.ink, c.ink),
      BannerTone.danger => (c.dangerSoft, c.danger, c.ink),
      BannerTone.neutral => (c.surfaceAlt, c.inkMuted, c.ink),
    };
    final hasTitle = title != null;
    return Semantics(
      button: onTap != null,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(hasTitle ? AppRadius.r20 : AppRadius.r16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: hasTitle
                ? const EdgeInsets.all(AppSpace.x16)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpace.x12),
            child: Row(
              children: [
                Icon(icon, size: hasTitle ? 22 : 18, color: accent),
                SizedBox(width: hasTitle ? AppSpace.x12 : 10),
                Expanded(
                  child: hasTitle
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title!, style: AppText.titleM.copyWith(color: accent)),
                            const SizedBox(height: 2),
                            Text(text, style: AppText.bodyM.copyWith(color: body)),
                          ],
                        )
                      : Text(text, style: AppText.labelM.copyWith(color: body)),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpace.x8),
                  Icon(LucideIcons.chevronRight, size: 18, color: accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A green tick and one line of plain reassurance.
class CheckLine extends StatelessWidget {
  const CheckLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(LucideIcons.check, size: 16, color: c.real),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.bodyM.copyWith(color: c.ink))),
      ],
    );
  }
}

/// Icon tile, title and one or two lines: nothing here yet, or coming soon.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: icon, size: 88, muted: true),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: AppText.displayM.copyWith(color: c.ink)),
            const SizedBox(height: AppSpace.x8),
            Text(body, textAlign: TextAlign.center, style: AppText.bodyL.copyWith(color: c.inkMuted)),
            if (action != null) ...[const SizedBox(height: AppSpace.x20), action!],
          ],
        ),
      ),
    );
  }
}

/// A placeholder row shown while the payment list loads.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.r10)),
        );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: 14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AppRadius.r20)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.r14)),
            ),
            const SizedBox(width: AppSpace.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [bar(140, 14), const SizedBox(height: 10), bar(90, 12)],
              ),
            ),
            bar(44, 14),
          ],
        ),
      ),
    );
  }
}

/// Loading, with skeleton rows instead of a spinner on a blank page.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.x8),
            const SkeletonRow(),
          ],
        ],
      ),
    );
  }
}

/// A full-screen message with an optional retry, for load failures.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.alertCircle,
      title: 'Something went wrong',
      body: message,
      action: onRetry == null
          ? null
          : TextButton(
              onPressed: onRetry,
              child: Text('Try again', style: AppText.labelL.copyWith(color: context.colors.ink)),
            ),
    );
  }
}
