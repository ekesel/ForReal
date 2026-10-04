import 'package:flutter/material.dart';

import '../core/widgets.dart';

/// Shown for a moment while the stored session is read.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'ForReal is starting',
          child: Text('ForReal', style: AppText.displayL.copyWith(color: c.ink)),
        ),
      ),
    );
  }
}
