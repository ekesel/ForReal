import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'dashed_border.dart';

enum AppChipVariant {
  /// Outlined, unselected.
  normal,

  /// Ink fill.
  selected,

  /// An AI guess: dashed outline, spark, muted text. Never green.
  guess,

  /// Confirmed by a real payment or by the user: green with a check.
  real,
}

/// A 38 px pill inside a 48 px touch target.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.normal,
    this.onTap,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final AppChipVariant variant;
  final VoidCallback? onTap;

  /// Overrides the leading icon (guess and real have their own).
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fill, Color text, Color? border, IconData? leading) = switch (variant) {
      AppChipVariant.normal => (c.surface, c.ink, c.line, icon),
      AppChipVariant.selected => (c.ink, c.onInk, null, icon),
      AppChipVariant.guess => (c.surface, c.inkMuted, null, icon ?? LucideIcons.sparkle),
      AppChipVariant.real => (c.realSoft, c.real, null, icon ?? LucideIcons.check),
    };
    Widget pill = Container(
      constraints: const BoxConstraints(minHeight: AppSize.chip),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: border == null ? null : Border.all(color: border, width: AppSize.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            Icon(leading, size: 14, color: text),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelM.copyWith(color: text),
            ),
          ),
        ],
      ),
    );
    if (variant == AppChipVariant.guess) {
      pill = DashedBorder(color: c.inkFaint, radius: AppRadius.pill, child: pill);
    }
    final selected = variant == AppChipVariant.selected;
    return Semantics(
      button: onTap != null,
      selected: onTap != null ? selected : null,
      label: semanticLabel ?? (variant == AppChipVariant.guess ? '$label, guessed' : label),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touch),
          child: Center(widthFactor: 1, heightFactor: 1, child: pill),
        ),
      ),
    );
  }
}
