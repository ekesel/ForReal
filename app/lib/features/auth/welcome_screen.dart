import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';

/// The first screen before sign-in. Always dark: ink background in both themes,
/// so it uses the light palette's ink side on purpose.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _p = AppColors.light;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _p.ink,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.x24, AppSpace.x20, AppSpace.x24, AppSpace.x24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ForReal', style: AppText.titleL.copyWith(color: _p.brand)),
                        const SizedBox(height: AppSpace.x20),
                        const ExcludeSemantics(child: _Art()),
                        const Spacer(),
                        const SizedBox(height: AppSpace.x20),
                        Semantics(
                          header: true,
                          child: Text(
                            'Where people actually pay.',
                            style: AppText.displayXL.copyWith(color: _p.onInk),
                          ),
                        ),
                        const SizedBox(height: AppSpace.x20),
                        Text(
                          'Reviews can be faked. A payment can’t. See the shops your neighbourhood goes back to.',
                          style: AppText.bodyL.copyWith(color: _p.inkFaint),
                        ),
                        const SizedBox(height: AppSpace.x20),
                        // On the dark screen the theme's own button colours would be
                        // wrong in dark mode, so this one is drawn with fixed tokens.
                        Theme(
                          data: appTheme(Brightness.light),
                          child: AppButton(
                            label: 'Get started',
                            variant: AppButtonVariant.brand,
                            onPressed: () => context.go('/sign-in'),
                          ),
                        ),
                        const SizedBox(height: AppSpace.x12),
                        Center(
                          child: Text(
                            'Your name stays hidden. Always your call.',
                            textAlign: TextAlign.center,
                            style: AppText.caption.copyWith(color: _p.inkFaint),
                          ),
                        ),
                      ],
                    ),
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

/// Three tilted cards: what the app is about, without a single star rating.
class _Art extends StatelessWidget {
  const _Art();

  static const _p = AppColors.light;

  @override
  Widget build(BuildContext context) {
    Widget card(String big, String small, Color fill, Color bigColor, Color smallColor, double turns) {
      return Transform.rotate(
        angle: turns * 3.14159 / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x20, vertical: 18),
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AppRadius.r24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(big, textScaler: TextScaler.noScaling, style: AppText.displayL.copyWith(color: bigColor)),
              const SizedBox(height: 2),
              Text(small, textScaler: TextScaler.noScaling, style: AppText.labelM.copyWith(color: smallColor)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 310,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned(left: 8, top: 68, child: card('142', 'people paid here', _p.brand, _p.onBrand, _p.onBrand, -4)),
          Positioned(left: 136, top: 20, child: card('68%', 'came back again', _p.surface, _p.ink, _p.inkMuted, 5)),
          Positioned(left: 58, top: 204, child: card('No stars.', 'only real payments', _p.realSoft, _p.real, _p.real, 3)),
        ],
      ),
    );
  }
}
