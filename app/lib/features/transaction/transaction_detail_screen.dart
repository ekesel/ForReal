import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../app/app_coordinator.dart';
import '../home/payment_list.dart';
import '../session/session_controller.dart';
import '../ui_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.clientTxnId});

  final String clientTxnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionProvider(clientTxnId));
    void back() => context.go('/');
    return Scaffold(
      body: transaction.when(
        loading: () => ScreenBody(children: [
          ScreenHeader(title: 'Payment', onBack: back),
          const SkeletonList(rows: 3),
        ]),
        error: (e, _) => ScreenBody(children: [
          ScreenHeader(title: 'Payment', onBack: back),
          ErrorState(message: errorText(e)),
        ]),
        data: (row) => row == null
            ? ScreenBody(children: [
                ScreenHeader(title: 'Payment', onBack: back),
                const EmptyState(
                  icon: LucideIcons.receipt,
                  title: 'Not on this phone',
                  body: 'This payment is no longer stored here.',
                ),
              ])
            : _Detail(row: row),
      ),
    );
  }
}

/// Whether this payment counts towards neighbourhood rankings, in plain words.
String rankingsAnswer(LocalTransaction row, {required bool communityOn}) {
  if (row.kind == 'person') return 'No, stays private';
  if (row.kind != 'merchant') return 'Not until it is a shop';
  return communityOn ? 'Yes, with no name' : 'No, rankings are off';
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.row});

  final LocalTransaction row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final merchant = row.merchantInfo;
    final state = row.state;
    final synced = row.syncState == 'synced';
    final base = '/txn/${row.clientTxnId}';
    final communityOn = ref.watch(sessionProvider.select((s) => s.consents.has(Purpose.communityRankings)));

    String? place;
    if (merchant != null) {
      final name = categoryLabel(merchant.category);
      place = merchant.isOnline ? '$name · online' : name;
    } else if (row.kind == 'person') {
      place = 'Person · private';
    }

    final actions = <Widget>[];
    if (row.syncState == 'failed') {
      actions.add(AppButton(
        label: 'Try again',
        variant: AppButtonVariant.secondary,
        onPressed: () async {
          await ref.read(localStoreProvider).retryFailed(row.clientTxnId);
          await ref.read(appCoordinatorProvider).kick();
        },
      ));
    } else if (synced) {
      switch (state) {
        case TxnState.needsShop:
          actions.add(AppButton(label: 'Shop or person?', onPressed: () => context.go('$base/payee')));
        case TxnState.person:
          actions.add(AppButton(
            label: 'This is actually a shop',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.go('$base/payee'),
          ));
        case TxnState.needsItems:
        case TxnState.done:
          actions.add(row.taggedItems.isEmpty
              ? AppButton(label: 'What did you get?', onPressed: () => context.go('$base/items'))
              : AppButton(
                  label: 'Edit what you got',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('$base/items'),
                ));
          actions.add(Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Different shop',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go('$base/payee'),
                ),
              ),
              const SizedBox(width: AppSpace.x8),
              Expanded(
                child: AppButton(
                  label: 'Not a shop',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go('$base/payee'),
                ),
              ),
            ],
          ));
      }
    }

    return ScreenBody(
      gap: 18,
      actions: actions,
      children: [
        ScreenHeader(
          title: 'Payment',
          onBack: () => context.go('/'),
          trailing: synced && row.kind == 'merchant'
              ? RoundIconButton(
                  icon: LucideIcons.pencil,
                  label: 'Edit what you got',
                  onPressed: () => context.go('$base/items'),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.x8),
          child: Column(
            children: [
              AvatarBox(
                size: 72,
                letter: state == TxnState.needsShop ? '?' : initialOf(row.title),
                icon: state == TxnState.person ? LucideIcons.user : null,
                color: state == TxnState.needsShop ? c.brandSoft : c.surfaceAlt,
                foreground: c.ink,
              ),
              const SizedBox(height: AppSpace.x12),
              Text(row.title, textAlign: TextAlign.center, style: AppText.displayM.copyWith(color: c.ink)),
              if (place != null) ...[
                const SizedBox(height: 6),
                Text(place, textAlign: TextAlign.center, style: AppText.bodyM.copyWith(color: c.inkMuted)),
              ],
              const SizedBox(height: 6),
              Text(amountText(row), textAlign: TextAlign.center, style: AppText.displayXL.copyWith(color: c.ink)),
              const SizedBox(height: 6),
              Text(
                dayAndTime(row.receivedAt, now: ref.watch(clockProvider)()),
                textAlign: TextAlign.center,
                style: AppText.labelM.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        if (row.taggedItems.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.x8,
            children: [
              for (final tag in row.taggedItems)
                AppChip(
                  label: tag.quantity > 1 ? '${tag.item.name} × ${tag.quantity}' : tag.item.name,
                  // Green only for the user's own answer; a guess stays dashed.
                  variant: tag.inferred ? AppChipVariant.guess : AppChipVariant.real,
                ),
            ],
          ),
        if (row.syncState == 'pending')
          const InfoBanner(
            icon: LucideIcons.cloudOff,
            text: 'Waiting to upload. You can tag it once it has reached the server.',
          ),
        if (row.syncState == 'failed')
          InfoBanner(
            icon: LucideIcons.alertCircle,
            tone: BannerTone.danger,
            title: 'Not uploaded',
            text: 'The server did not accept this payment: ${row.error ?? 'unknown reason'}',
          ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x16, vertical: AppSpace.x4),
          child: Column(
            children: [
              _Fact('Your bank calls them', row.payeeDisplay),
              _Fact('Counts in rankings', rankingsAnswer(row, communityOn: communityOn)),
              _Fact('Came from', row.fromHistory && row.amountExact != null ? 'Bank SMS, imported' : 'Bank SMS'),
              _Fact(
                'Amount',
                row.amountExact != null ? 'Stays on this phone' : 'Only the range is known',
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppText.bodyM.copyWith(color: c.inkMuted))),
          const SizedBox(width: AppSpace.x12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: AppText.labelM.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}
