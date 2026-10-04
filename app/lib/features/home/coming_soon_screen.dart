import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets.dart';
import 'tab_scaffold.dart';

/// Discover and Insights arrive in Phase 4. Until then each tab says, in one line,
/// what it will do. Nothing here is interactive.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen.discover({super.key})
      : tab = AppTab.discover,
        icon = LucideIcons.compass,
        description = 'The shops your neighbourhood actually goes back to, ranked by real payments.';

  const ComingSoonScreen.insights({super.key})
      : tab = AppTab.insights,
        icon = LucideIcons.barChart3,
        description = 'Where your own money goes, by shop and by what you bought.';

  final AppTab tab;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TabScaffold(
      tab: tab,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.x8, AppSpace.screen, AppSpace.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(tab.label, style: AppText.displayL.copyWith(color: c.ink))),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTile(icon: icon, size: 88),
                      const SizedBox(height: AppSpace.x16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.brandSoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('Coming soon', style: AppText.labelS.copyWith(color: c.ink)),
                      ),
                      const SizedBox(height: AppSpace.x12),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: AppText.bodyL.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
