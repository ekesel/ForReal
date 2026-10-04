import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A flat surface card: no shadow, optional 1 px line, 1.5 px ink when selected.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.x16),
    this.radius = AppRadius.r20,
    this.color,
    this.outlined = false,
    this.selected = false,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Defaults to the surface colour.
  final Color? color;

  /// Draw the 1 px `line` border.
  final bool outlined;

  /// Draw the 1.5 px `ink` border (wins over [outlined]).
  final bool selected;

  /// Overrides the border colour, for example green around a confirmed suggestion.
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    BorderSide side = BorderSide.none;
    if (borderColor != null) {
      side = BorderSide(color: borderColor!, width: AppSize.lineStrong);
    } else if (selected) {
      side = BorderSide(color: c.ink, width: AppSize.lineStrong);
    } else if (outlined) {
      side = BorderSide(color: c.line, width: AppSize.line);
    }
    return Material(
      color: color ?? c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
