import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A text field with its label above and an optional helper line below.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefix,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.maxLength,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.style,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;

  /// Fixed text before the input, such as "+91".
  final String? prefix;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget? leading;
    if (prefix != null) {
      leading = Padding(
        padding: const EdgeInsets.only(left: AppSpace.x16, right: AppSpace.x12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prefix!, style: AppText.titleM.copyWith(color: c.inkMuted)),
            const SizedBox(width: AppSpace.x12),
            Container(width: 1, height: 24, color: c.line),
          ],
        ),
      );
    } else if (prefixIcon != null) {
      leading = Icon(prefixIcon, size: 20, color: c.inkMuted);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppText.labelM.copyWith(color: c.inkMuted)),
          const SizedBox(height: AppSpace.x8),
        ],
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: (style ?? AppText.bodyL).copyWith(color: c.ink),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            counterText: '',
            prefixIcon: leading,
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
            // Announced by screen readers; the visible label is the Text above.
            semanticCounterText: '',
          ),
        ),
        if (helper != null && errorText == null) ...[
          const SizedBox(height: AppSpace.x8),
          Text(helper!, style: AppText.caption.copyWith(color: c.inkMuted)),
        ],
      ],
    );
  }
}
