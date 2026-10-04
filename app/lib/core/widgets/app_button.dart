import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'feedback.dart';

enum AppButtonVariant {
  /// Ink fill: the main action of a screen.
  primary,

  /// Marigold fill: the welcome screen's call to action.
  brand,

  /// Outline: a second, equally valid action.
  secondary,

  /// Text only: skip, or a quieter alternative.
  ghost,

  /// Soft red: destructive.
  danger,
}

/// The app's button. Shows a spinner and ignores taps while its action runs; an
/// error thrown by the action is shown as a snack bar.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.quiet = false,
  });

  final String label;

  /// Null disables the button.
  final FutureOr<void> Function()? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Fill the available width (the default) or hug the label.
  final bool expand;

  /// Force the loading state from outside.
  final bool loading;

  /// No spinner while the action runs. For actions that open a sheet and wait for
  /// the user: a spinner behind the sheet would be noise.
  final bool quiet;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _running = false;

  bool get _busy => _running || widget.loading;

  Future<void> _run() async {
    final action = widget.onPressed;
    if (action == null || _busy) return;
    setState(() => _running = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null;
    final (Color? fill, Color text, Color? border) = switch (widget.variant) {
      AppButtonVariant.primary => (c.ink, c.onInk, null),
      AppButtonVariant.brand => (c.brand, c.onBrand, null),
      AppButtonVariant.secondary => (null, c.ink, c.ink),
      AppButtonVariant.ghost => (null, c.inkMuted, null),
      AppButtonVariant.danger => (c.dangerSoft, c.danger, null),
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.r16),
      side: border == null ? BorderSide.none : BorderSide(color: border, width: AppSize.lineStrong),
    );
    final content = _busy && !widget.quiet
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: text),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: text),
                const SizedBox(width: AppSpace.x8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelL.copyWith(color: text),
                ),
              ),
            ],
          );
    final button = Semantics(
      button: true,
      enabled: enabled && !_busy,
      label: widget.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: fill ?? Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled && !_busy ? _run : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.button),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.x24, vertical: AppSpace.x8),
                // Never taller than its content needs (at least 54), whatever the parent offers.
                child: Center(widthFactor: widget.expand ? null : 1, heightFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
