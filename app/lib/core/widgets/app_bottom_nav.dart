import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

enum AppTab {
  payments('Payments', LucideIcons.receiptText),
  discover('Discover', LucideIcons.compass),
  insights('Insights', LucideIcons.barChart3),
  you('You', LucideIcons.user);

  const AppTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The four tabs. The active one has a marigold pill behind its icon.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.active, required this.onSelect});

  final AppTab active;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpace.x8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.x8, 6, AppSpace.x8, 2),
          child: Row(
            children: [
              for (final tab in AppTab.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: tab == active,
                    label: tab.label,
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => onSelect(tab),
                      radius: 44,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: AppSize.touch + 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: AppMotion.quick,
                              width: 60,
                              height: 32,
                              decoration: BoxDecoration(
                                color: tab == active ? c.brand : c.brand.withValues(alpha: 0),
                                borderRadius: BorderRadius.circular(AppRadius.r16),
                              ),
                              child: Icon(tab.icon, size: 22, color: tab == active ? c.onBrand : c.inkMuted),
                            ),
                            const SizedBox(height: AppSpace.x4),
                            Text(
                              tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.labelS.copyWith(color: tab == active ? c.ink : c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
