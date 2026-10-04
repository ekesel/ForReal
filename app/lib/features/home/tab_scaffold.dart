import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';

/// Where each tab lives. Tabs are ordinary routes; the bar just goes to them.
String tabPath(AppTab tab) => switch (tab) {
      AppTab.payments => '/',
      AppTab.discover => '/discover',
      AppTab.insights => '/insights',
      AppTab.you => '/settings',
    };

/// A top-level screen with the bottom navigation.
class TabScaffold extends StatelessWidget {
  const TabScaffold({super.key, required this.tab, required this.body});

  final AppTab tab;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: AppBottomNav(
        active: tab,
        onSelect: (next) {
          if (next != tab) context.go(tabPath(next));
        },
      ),
    );
  }
}
