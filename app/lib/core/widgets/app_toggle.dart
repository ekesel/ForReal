import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// On is green: the user has said yes to something real.
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;

  /// Null disables the toggle.
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: 52,
          height: AppSize.touch,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: AnimatedContainer(
                duration: AppMotion.quick,
                width: 52,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? c.real : c.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: AnimatedAlign(
                  duration: AppMotion.quick,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
