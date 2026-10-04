import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../capture/transaction_source.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';
import '../app/app_coordinator.dart';
import '../consent/notices.dart';
import '../session/session_controller.dart';
import '../ui_providers.dart';
import 'payment_list.dart';
import 'tab_scaffold.dart';

/// The user's payments, newest first, from the local database.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.untaggedOnly = false});

  /// Start with only payments that still need an answer (the evening summary opens this).
  final bool untaggedOnly;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late PaymentFilter _filter = widget.untaggedOnly ? PaymentFilter.needsYou : PaymentFilter.all;

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.untaggedOnly != oldWidget.untaggedOnly) {
      _filter = widget.untaggedOnly ? PaymentFilter.needsYou : PaymentFilter.all;
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(smsPermissionProvider);
    final outcome = await ref.read(appCoordinatorProvider).reconcile();
    if (!mounted || outcome == null) return;
    if (outcome.retryLater) showMessage(context, 'Could not reach the server. Showing what is on this phone.');
    if (outcome.error != null) showError(context, outcome.error!);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final transactions = ref.watch(transactionsProvider);
    final importing = ref.watch(historyImportRunningProvider);
    final all = transactions.value;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text('Payments', style: AppText.displayL.copyWith(color: c.ink))),
            ),
            Semantics(
              button: true,
              label: 'You: privacy and data',
              excludeSemantics: true,
              child: InkResponse(
                onTap: () => context.go('/settings'),
                radius: 28,
                child: SizedBox(
                  width: AppSize.touch,
                  height: AppSize.touch,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                      child: Icon(LucideIcons.user, size: 20, color: c.onInk),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x12)),
      const SliverToBoxAdapter(child: CaptureBanner()),
      if (importing)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: AppSpace.x16),
            child: InfoBanner(icon: LucideIcons.clock, text: 'Bringing in past payments…'),
          ),
        ),
    ];

    if (transactions.hasError && all == null) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(
          message: errorText(transactions.error!),
          onRetry: () => ref.invalidate(transactionsProvider),
        ),
      ));
    } else if (all == null) {
      // No spinner on a blank page: the shape of what is coming.
      slivers.add(const SliverToBoxAdapter(child: SkeletonList()));
    } else if (all.isEmpty) {
      slivers.add(const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: LucideIcons.receiptText,
          title: 'Nothing here yet',
          body: 'Pay any shop by UPI and it lands here within a minute.',
        ),
      ));
    } else {
      final now = ref.watch(clockProvider)();
      final summary = weekSummary(all, now: now);
      final rows = [for (final r in all) if (matchesFilter(r, _filter)) r];
      slivers.addAll([
        SliverToBoxAdapter(
          child: _WeekCard(
            summary: summary,
            onNeedsYou: summary.needsYou == 0 ? null : () => setState(() => _filter = PaymentFilter.needsYou),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x8)),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (filter, label) in [
                  (PaymentFilter.all, 'All'),
                  (PaymentFilter.needsYou, summary.needsYou > 0 ? 'Needs you · ${summary.needsYou}' : 'Needs you'),
                  (PaymentFilter.shops, 'Shops'),
                  (PaymentFilter.people, 'People'),
                ]) ...[
                  AppChip(
                    label: label,
                    variant: _filter == filter ? AppChipVariant.selected : AppChipVariant.normal,
                    onTap: () => setState(() => _filter = filter),
                  ),
                  const SizedBox(width: AppSpace.x8),
                ],
              ],
            ),
          ),
        ),
        if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: _filter == PaymentFilter.needsYou ? LucideIcons.check : LucideIcons.receipt,
              title: _filter == PaymentFilter.needsYou ? 'All caught up' : 'Nothing in this view',
              body: _filter == PaymentFilter.needsYou
                  ? 'Every payment has its answer.'
                  : 'No payments match this filter yet.',
            ),
          )
        else
          for (final group in groupByDay(rows, now: now)) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.x8, bottom: AppSpace.x12),
                child: SectionLabel(group.label),
              ),
            ),
            SliverList.separated(
              itemCount: group.rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.x8),
              itemBuilder: (context, i) => TransactionRow(row: group.rows[i]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x8)),
          ],
      ]);
    }

    return TabScaffold(
      tab: AppTab.payments,
      body: RefreshIndicator(
        color: c.ink,
        backgroundColor: c.surface,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.x8, AppSpace.screen, AppSpace.x24),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown whenever new payments are not being recorded: Android does not let the
/// app see SMS, or the required consent is missing. Tapping it goes to the fix.
class CaptureBanner extends ConsumerWidget {
  const CaptureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(smsPermissionProvider).value;
    final consented = ref.watch(sessionProvider.select((s) => s.mayCapture));
    final smsMissing = permission != null && permission != SmsPermission.granted;
    if (consented && !smsMissing) return const SizedBox.shrink();

    final String text;
    final Future<void> Function() fix;
    if (!consented) {
      text = captureOffNeedsConsent;
      fix = () async => context.go('/settings');
    } else if (permission == SmsPermission.deniedForever) {
      text = captureOffNeedsSettings;
      fix = () async {
        await ref.read(openAppSettingsProvider)();
        ref.invalidate(smsPermissionProvider);
      };
    } else {
      text = captureOffNeedsSms;
      fix = () async {
        // Android stops showing its prompt after repeated refusals; then only the
        // system settings page can change it.
        final result = await ref.read(captureControlProvider).requestSmsPermission();
        if (result == SmsPermission.deniedForever) await ref.read(openAppSettingsProvider)();
        ref.invalidate(smsPermissionProvider);
      };
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x16),
      child: InfoBanner(
        icon: LucideIcons.messageSquare,
        tone: BannerTone.danger,
        title: captureOffTitle,
        text: text,
        onTap: fix,
      ),
    );
  }
}

/// This week's total from the exact amounts on this phone, and what still needs an answer.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.summary, required this.onNeedsYou});

  final WeekSummary summary;
  final VoidCallback? onNeedsYou;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = summary.count;
    final needs = summary.needsYou;
    return Container(
      padding: const EdgeInsets.all(AppSpace.x20),
      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(AppRadius.r24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('This week', color: c.inkFaint),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(formatRupees(summary.total.roundToDouble()), style: AppText.displayXL.copyWith(color: c.onInk)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  count == 1 ? '1 payment' : '$count payments',
                  style: AppText.bodyM.copyWith(color: c.inkFaint),
                ),
              ),
            ],
          ),
          if (needs > 0) ...[
            const SizedBox(height: 14),
            Semantics(
              button: true,
              child: Material(
                color: c.brand,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onNeedsYou,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSize.touch),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              needs == 1 ? '1 payment needs a quick answer' : '$needs payments need a quick answer',
                              style: AppText.labelM.copyWith(color: c.onBrand),
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 18, color: c.onBrand),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A local payment drawn as a [PaymentRow].
class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.row});

  final LocalTransaction row;

  @override
  Widget build(BuildContext context) {
    final mark = syncMark(row);
    final detail = itemsText(row);
    return PaymentRow(
      title: row.title,
      state: rowStateOf(row),
      detail: detail.isEmpty ? null : detail,
      amount: amountText(row),
      time: formatTime(row.receivedAt),
      statusIcon: mark?.icon,
      statusLabel: mark?.label,
      onTap: () => context.go('/txn/${row.clientTxnId}'),
    );
  }
}
