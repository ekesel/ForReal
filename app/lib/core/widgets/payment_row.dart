import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'basics.dart';

/// Where a payment stands, as the list shows it.
enum PaymentRowState {
  /// Unknown payee: marigold "Shop or person?".
  needsShop,

  /// A shop with nothing tagged: soft marigold "What did you get?".
  needsItems,

  /// Tagged by the user: green check and the items.
  done,

  /// Tagged by the app's guess: spark and "Tea, guessed". Never green.
  guessed,

  /// A person: lock and "Person · private".
  person,
}

/// One payment in the list.
class PaymentRow extends StatelessWidget {
  const PaymentRow({
    super.key,
    required this.title,
    required this.state,
    required this.amount,
    required this.time,
    this.detail,
    this.statusIcon,
    this.statusLabel,
    this.onTap,
  });

  /// Shop name once confirmed, otherwise the payee as the bank wrote it.
  final String title;
  final PaymentRowState state;

  /// "₹55", or a range when the exact amount is not on this phone.
  final String amount;
  final String time;

  /// The items, for [PaymentRowState.done] and [PaymentRowState.guessed].
  final String? detail;

  /// Upload state, when it is not simply "on the server".
  final IconData? statusIcon;
  final String? statusLabel;
  final VoidCallback? onTap;

  String get _stateText => switch (state) {
        PaymentRowState.needsShop => 'Shop or person?',
        PaymentRowState.needsItems => 'What did you get?',
        PaymentRowState.done => detail ?? 'Tagged',
        PaymentRowState.guessed => '${detail ?? 'Items'}, guessed',
        PaymentRowState.person => 'Person · private',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final needsShop = state == PaymentRowState.needsShop;
    return Semantics(
      button: onTap != null,
      label: '$title, $amount, $time. $_stateText${statusLabel == null ? '' : '. $statusLabel'}',
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.r20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: 14),
            child: Row(
              children: [
                AvatarBox(
                  letter: needsShop ? '?' : initialOf(title),
                  icon: state == PaymentRowState.person ? LucideIcons.user : null,
                  color: needsShop ? c.brandSoft : c.surfaceAlt,
                  foreground: c.ink,
                ),
                const SizedBox(width: AppSpace.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleM.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: AppSpace.x4),
                      // A short fade and slide when the state changes, nothing more.
                      AnimatedSwitcher(
                        duration: AppMotion.quick,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, ?current],
                        ),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(key: ValueKey('$state|$detail'), child: _sub(c)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.x12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amount, style: AppText.labelL.copyWith(color: c.ink)),
                    const SizedBox(height: AppSpace.x4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (statusIcon != null) ...[
                          Icon(statusIcon, size: 13, color: c.inkMuted),
                          const SizedBox(width: 4),
                        ],
                        Text(time, style: AppText.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sub(AppColors c) {
    Widget pill(String text, Color fill, Color fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.labelS.copyWith(color: fg)),
        );
    Widget line(IconData icon, Color iconColor, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyM.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        );
    return switch (state) {
      PaymentRowState.needsShop => pill('Shop or person?', c.brand, c.onBrand),
      PaymentRowState.needsItems => pill('What did you get?', c.brandSoft, c.ink),
      PaymentRowState.done => line(LucideIcons.check, c.real, _stateText),
      PaymentRowState.guessed => line(LucideIcons.sparkle, c.inkMuted, _stateText),
      PaymentRowState.person => line(LucideIcons.lock, c.inkMuted, _stateText),
    };
  }
}
