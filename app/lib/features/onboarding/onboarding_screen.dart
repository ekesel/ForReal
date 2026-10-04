import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../capture/transaction_source.dart';
import '../../core/feature_flags.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../app/app_coordinator.dart';
import '../consent/notices.dart';
import '../session/session_controller.dart';
import '../ui_providers.dart';

enum _Step { paymentMessages, community, location, notifications, history }

/// First-run flow. Only the first step (payment messages) is required; every
/// later step can be skipped and changed afterwards under "You".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final List<_Step> _steps;
  int _index = 0;
  bool _community = false;
  bool _insights = false;

  /// Months of history to import; null until the user (or the default) decides.
  int? _historyMonths;

  @override
  void initState() {
    super.initState();
    // Someone who finished onboarding before and is here because the consent was
    // withdrawn only needs the consent again; the router takes them back to the app
    // as soon as it is granted.
    _steps = ref.read(sessionProvider).onboardingDone ? const [_Step.paymentMessages] : _Step.values;
  }

  SessionController get _session => ref.read(sessionProvider.notifier);

  Future<void> _next() async {
    if (_index < _steps.length - 1) {
      setState(() => _index++);
      return;
    }
    await _session.completeOnboarding();
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  /// The required step: grant the consent, then let Android ask for SMS access.
  /// Refusing the Android prompt still moves on; the app then shows "Capture is off".
  Future<void> _allowPaymentMessages() async {
    if (!ref.read(sessionProvider).consents.has(Purpose.privateAnalytics)) {
      await _session.setConsent(Purpose.privateAnalytics, true);
    }
    await ref.read(captureControlProvider).requestSmsPermission();
    ref.invalidate(smsPermissionProvider);
    await _next();
  }

  /// "Not now" on the required step cannot skip it: explain, and offer the way out.
  Future<void> _declinePaymentMessages() async {
    final signOut = await confirmDialog(
      context,
      title: 'ForReal needs this to work',
      message: paymentMessagesRequired,
      confirmLabel: 'Sign out',
    );
    if (signOut) await _session.signOut();
  }

  Future<void> _saveCommunity() async {
    if (_community) {
      await _session.setConsent(Purpose.communityRankings, true);
      if (merchantInsightsEnabled && _insights) await _session.setConsent(Purpose.merchantInsights, true);
    }
    await _next();
  }

  Future<void> _allowLocation() async {
    await _session.setConsent(Purpose.location, true);
    await ref.read(locationServiceProvider).requestPermission();
    ref.invalidate(locationPermissionProvider);
    await _next();
  }

  Future<void> _allowNotifications() async {
    await ref.read(notificationPermissionsProvider).request();
    ref.invalidate(notificationsEnabledProvider);
    await _next();
  }

  Future<void> _finish(int months) async {
    await _session.completeOnboarding();
    if (months > 0) {
      // Runs while the user is already on the home screen.
      ref.read(appCoordinatorProvider).importHistory(Duration(days: 30 * months)).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppMotion.quick,
        child: KeyedSubtree(key: ValueKey(step), child: _body(step)),
      ),
    );
  }

  Widget _header() => StepHeader(step: _index + 1, total: _steps.length, onBack: _index > 0 ? _back : null);

  Widget _checks(StepCopy copy) => Column(
        children: [
          for (final (i, point) in copy.points.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpace.x12),
            CheckLine(point.$2),
          ],
        ],
      );

  Widget _fullNotice(Notice notice) => Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () => noticeSheet(context, notice),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.touch),
            child: Align(
              widthFactor: 1,
              alignment: Alignment.centerLeft,
              child: Text(
                'Read the full notice',
                style: AppText.labelM.copyWith(
                  color: context.colors.ink,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _body(_Step step) {
    final c = context.colors;
    switch (step) {
      case _Step.paymentMessages:
        return ScreenBody(
          gap: 22,
          actions: [
            AppButton(label: 'Allow and continue', onPressed: _allowPaymentMessages),
            AppButton(
              label: 'Not now',
              variant: AppButtonVariant.ghost,
              quiet: true,
              onPressed: _declinePaymentMessages,
            ),
          ],
          children: [
            _header(),
            const Align(alignment: Alignment.centerLeft, child: IconTile(icon: LucideIcons.messageSquare)),
            TitleBlock(title: paymentMessagesStep.title, subtitle: paymentMessagesStep.subtitle),
            Column(
              children: [
                _Reason(
                  icon: LucideIcons.check,
                  iconColor: c.real,
                  tile: c.realSoft,
                  title: paymentMessagesStep.points[0].$1,
                  body: paymentMessagesStep.points[0].$2,
                ),
                const SizedBox(height: AppSpace.x16),
                _Reason(
                  icon: LucideIcons.smartphone,
                  iconColor: c.ink,
                  tile: c.surfaceAlt,
                  title: paymentMessagesStep.points[1].$1,
                  body: paymentMessagesStep.points[1].$2,
                ),
                const SizedBox(height: AppSpace.x16),
                _Reason(
                  icon: LucideIcons.x,
                  iconColor: c.danger,
                  tile: c.surfaceAlt,
                  title: paymentMessagesStep.points[2].$1,
                  body: paymentMessagesStep.points[2].$2,
                ),
              ],
            ),
            _fullNotice(privateAnalyticsNotice),
          ],
        );
      case _Step.community:
        return ScreenBody(
          gap: 22,
          actions: [
            AppButton(label: 'Continue', onPressed: _saveCommunity),
            AppButton(label: 'Skip for now', variant: AppButtonVariant.ghost, onPressed: _next),
          ],
          children: [
            _header(),
            const Align(alignment: Alignment.centerLeft, child: IconTile(icon: LucideIcons.users)),
            TitleBlock(title: communityStep.title, subtitle: communityStep.subtitle),
            _ToggleCard(
              title: communityStep.points[0].$1,
              body: communityStep.points[0].$2,
              value: _community,
              onChanged: (v) => setState(() {
                _community = v;
                if (!v) _insights = false;
              }),
            ),
            if (merchantInsightsEnabled)
              _ToggleCard(
                title: communityStep.points[1].$1,
                body: communityStep.points[1].$2,
                value: _insights,
                // Depends on community rankings.
                onChanged: _community ? (v) => setState(() => _insights = v) : null,
              ),
            InfoBanner(icon: LucideIcons.shieldCheck, tone: BannerTone.real, text: communityStep.points[2].$2),
            _fullNotice(communityRankingsNotice),
          ],
        );
      case _Step.location:
        return ScreenBody(
          gap: 22,
          actions: [
            AppButton(label: 'Allow location', onPressed: _allowLocation),
            AppButton(label: 'Skip', variant: AppButtonVariant.ghost, onPressed: _next),
          ],
          children: [
            _header(),
            const Align(alignment: Alignment.centerLeft, child: IconTile(icon: LucideIcons.mapPin)),
            TitleBlock(title: locationStep.title, subtitle: locationStep.subtitle),
            ExcludeSemantics(
              child: Container(
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.r24)),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                  child: Icon(LucideIcons.mapPin, size: 22, color: c.onBrand),
                ),
              ),
            ),
            _checks(locationStep),
            _fullNotice(locationNotice),
          ],
        );
      case _Step.notifications:
        return ScreenBody(
          gap: 22,
          actions: [
            AppButton(label: 'Turn on notifications', onPressed: _allowNotifications),
            AppButton(label: 'Skip', variant: AppButtonVariant.ghost, onPressed: _next),
          ],
          children: [
            _header(),
            const Align(alignment: Alignment.centerLeft, child: IconTile(icon: LucideIcons.bell)),
            TitleBlock(title: notificationsStep.title, subtitle: notificationsStep.subtitle),
            const _NotificationPreview(),
            _checks(notificationsStep),
          ],
        );
      case _Step.history:
        final allowed = ref.watch(smsPermissionProvider).value == SmsPermission.granted;
        // The design recommends last month. Without SMS access only "start fresh" is possible.
        final months = allowed ? (_historyMonths ?? 1) : 0;
        return ScreenBody(
          gap: 22,
          actions: [AppButton(label: 'Finish setup', onPressed: () => _finish(months))],
          children: [
            _header(),
            const Align(alignment: Alignment.centerLeft, child: IconTile(icon: LucideIcons.clock)),
            TitleBlock(title: historyStep.title, subtitle: historyStep.subtitle),
            Column(
              children: [
                _Option(
                  title: historyStep.points[0].$1,
                  body: historyStep.points[0].$2,
                  badge: 'Recommended',
                  selected: months == 1,
                  onTap: allowed ? () => setState(() => _historyMonths = 1) : null,
                ),
                const SizedBox(height: AppSpace.x12),
                _Option(
                  title: historyStep.points[1].$1,
                  body: historyStep.points[1].$2,
                  selected: months == 3,
                  onTap: allowed ? () => setState(() => _historyMonths = 3) : null,
                ),
                const SizedBox(height: AppSpace.x12),
                _Option(
                  title: historyStep.points[2].$1,
                  body: historyStep.points[2].$2,
                  selected: months == 0,
                  onTap: () => setState(() => _historyMonths = 0),
                ),
              ],
            ),
            if (!allowed)
              const InfoBanner(
                icon: LucideIcons.messageSquare,
                text: 'Past payments can be imported once ForReal can read bank messages. '
                    'You can do this later under You.',
              ),
          ],
        );
    }
  }
}

/// Icon in a small tile, a title and one line: one reason on the first step.
class _Reason extends StatelessWidget {
  const _Reason({
    required this.icon,
    required this.iconColor,
    required this.tile,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final Color tile;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(AppSpace.x12)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleM.copyWith(color: c.ink)),
              const SizedBox(height: 2),
              Text(body, style: AppText.bodyM.copyWith(color: c.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({required this.title, required this.body, required this.value, required this.onChanged});

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      outlined: true,
      selected: value,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.titleM.copyWith(color: c.ink)),
                const SizedBox(height: AppSpace.x4),
                Text(body, style: AppText.bodyM.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          AppToggle(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }
}

/// A picture of the prompt, so the user knows what they are saying yes to.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: AppCard(
        outlined: true,
        radius: AppRadius.r24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(AppSpace.x8)),
                  child: Text('F', textScaler: TextScaler.noScaling, style: AppText.labelS.copyWith(color: c.onBrand)),
                ),
                const SizedBox(width: AppSpace.x8),
                Text('ForReal · now', style: AppText.labelS.copyWith(color: c.inkMuted)),
              ],
            ),
            const SizedBox(height: AppSpace.x12),
            Text('Paid ₹55 at Sharma Tea Stall', style: AppText.titleM.copyWith(color: c.ink)),
            const SizedBox(height: AppSpace.x4),
            Text('For Tea?', style: AppText.bodyM.copyWith(color: c.inkMuted)),
            const SizedBox(height: AppSpace.x4),
            const Wrap(
              spacing: AppSpace.x8,
              children: [
                AppChip(label: 'Yes', variant: AppChipVariant.selected),
                AppChip(label: 'Something else'),
                AppChip(label: 'Not a shop'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A radio-style choice card. The selected one is ink.
class _Option extends StatelessWidget {
  const _Option({required this.title, required this.body, required this.selected, required this.onTap, this.badge});

  final String title;
  final String body;
  final String? badge;
  final bool selected;

  /// Null disables the option.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onInk : c.ink;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null && !selected ? 0.45 : 1,
        child: AppCard(
          color: selected ? c.ink : c.surface,
          outlined: !selected,
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpace.x8,
                      runSpacing: AppSpace.x4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(title, style: AppText.titleM.copyWith(color: fg)),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x8, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.brand,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(badge!, style: AppText.labelS.copyWith(color: c.onBrand)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.x4),
                    Text(body, style: AppText.bodyM.copyWith(color: selected ? c.inkFaint : c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.brand : null,
                  border: selected ? null : Border.all(color: c.inkFaint, width: AppSize.lineStrong),
                ),
                child: selected ? Icon(LucideIcons.check, size: 14, color: c.onBrand) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
