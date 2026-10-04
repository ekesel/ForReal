import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The layout every pushed screen shares: scrolling content with the screen
/// padding, and actions pinned to the bottom.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.children, this.actions = const [], this.gap = AppSpace.x20});

  final List<Widget> children;

  /// Buttons kept above the bottom edge, stacked with 8 px between them.
  final List<Widget> actions;

  /// Space between [children].
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.x8, AppSpace.screen, AppSpace.x16),
              itemCount: children.length,
              separatorBuilder: (_, _) => SizedBox(height: gap),
              itemBuilder: (_, i) => children[i],
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.x8, AppSpace.screen, AppSpace.x16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpace.x8),
                    actions[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Title and one supporting line at the top of a step or a form.
class TitleBlock extends StatelessWidget {
  const TitleBlock({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.displayL.copyWith(color: c.ink))),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: AppText.bodyL.copyWith(color: c.inkMuted)),
        ],
      ],
    );
  }
}
